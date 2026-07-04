<?php

/**
 * Copyright (C) 2026 NG Technologies.
 * Part of the NGSign connector for Maarch Courrier.
 * Licensed under the GNU General Public License v3.0 (see LICENSE).
 */

/**
 * NGSign external signatory book connector for Maarch Courrier 2301.
 *
 * Implements the native Maarch parapheur contract:
 *   - sendDatas()          : called by Action\controllers\ExternalSignatoryBookTrait
 *                            when the system action "Envoyer vers un parapheur externe" runs.
 *   - retrieveSignedMails(): called by bin/signatureBook/process_mailsFromSignatoryBook.php
 *                            to poll NGSign and re-inject the signed PDF.
 *
 * Configuration is read from modules/visa/xml/remoteSignatoryBooks.xml, block <id>ngsign</id>.
 * The only mandatory external settings are <url> and <token>.
 */

namespace ExternalSignatoryBook\ngsign\controllers;

use Attachment\models\AttachmentModel;
use Attachment\models\AttachmentTypeModel;
use Convert\controllers\ConvertPdfController;
use Docserver\models\DocserverModel;
use ExternalSignatoryBook\ngsign\Infrastructure\NgsignClient;
use Resource\models\ResModel;
use SrcCore\models\DatabaseModel;
use User\models\UserModel;

class NgsignController
{
    /**
     * SEND: push the signable document(s) of a resource to NGSign.
     *
     * @param array $aArgs ['config' => [...], 'resIdMaster' => int, ...]
     * @return array ['sended' => ['attachments_coll'=>[resId=>externalId], 'letterbox_coll'=>[...]], 'historyInfos'=>string]
     *               or ['error' => string]
     */
    public static function sendDatas(array $aArgs): array
    {
        $config      = $aArgs['config'];
        $resIdMaster = (int)$aArgs['resIdMaster'];

        $client = self::buildClient($config);
        if (!empty($client['error'])) {
            return ['error' => $client['error']];
        }
        $client = $client['client'];

        $signer = self::resolveSigner($resIdMaster);
        if (!empty($signer['error'])) {
            return ['error' => $signer['error']];
        }

        $attachmentToFreeze = [];

        // --- Signable attachments -------------------------------------------------
        $attachments = AttachmentModel::get([
            'select' => ['res_id', 'title', 'attachment_type'],
            'where'  => [
                'res_id_master = ?',
                'attachment_type not in (?)',
                "status NOT IN ('DEL','OBS','FRZ','TMP','SEND_MASS','SIGN')",
                "in_signature_book = 'true'"
            ],
            'data'   => [$resIdMaster, ['signed_response']]
        ]);

        $signableByType = AttachmentTypeModel::get(['select' => ['type_id', 'signable']]);
        $signableByType = array_column($signableByType, 'signable', 'type_id');

        foreach ($attachments as $attachment) {
            // Skip non-signable attachment types (annexes) like the native providers do.
            if (empty($signableByType[$attachment['attachment_type']])) {
                continue;
            }

            $pdfPath = self::resolvePdfPath((int)$attachment['res_id'], 'attachments_coll');
            if (empty($pdfPath)) {
                return ['error' => 'Attachment ' . $attachment['res_id'] . ' is not converted to PDF'];
            }

            $pushed = self::pushDocument($client, $config, $pdfPath, (string)$attachment['title'], $signer);
            if (!empty($pushed['error'])) {
                return ['error' => $pushed['error']];
            }

            $attachmentToFreeze['attachments_coll'][$attachment['res_id']] = $pushed['externalId'];
            self::track($resIdMaster, (int)$attachment['res_id'], $pushed, $signer);
        }

        // --- Main document (letterbox) if placed in the signature book ------------
        $letterbox = ResModel::get([
            'select' => ['res_id', 'subject', 'integrations', 'external_id'],
            'where'  => ['res_id = ?'],
            'data'   => [$resIdMaster]
        ]);
        if (!empty($letterbox[0])) {
            $integrations = json_decode($letterbox[0]['integrations'] ?? '{}', true);
            $externalId   = json_decode($letterbox[0]['external_id'] ?? '{}', true);
            if (!empty($integrations['inSignatureBook']) && empty($externalId['signatureBookId'])) {
                $pdfPath = self::resolvePdfPath($resIdMaster, 'letterbox_coll');
                if (empty($pdfPath)) {
                    return ['error' => 'Main document ' . $resIdMaster . ' is not converted to PDF'];
                }
                $pushed = self::pushDocument($client, $config, $pdfPath, (string)$letterbox[0]['subject'], $signer);
                if (!empty($pushed['error'])) {
                    return ['error' => $pushed['error']];
                }
                $attachmentToFreeze['letterbox_coll'][$resIdMaster] = $pushed['externalId'];
                self::track($resIdMaster, $resIdMaster, $pushed, $signer);
            }
        }

        if (empty($attachmentToFreeze)) {
            return ['error' => 'No signable document found for resource ' . $resIdMaster];
        }

        return ['sended' => $attachmentToFreeze, 'historyInfos' => 'Document(s) envoyé(s) au parapheur NGSign'];
    }

    /**
     * RETRIEVE: poll NGSign for each pending id and expose the signed PDF to the batch.
     *
     * @param array $aArgs ['config'=>[...], 'idsToRetrieve'=>[version=>[resId=>['external_id'=>..., ...]]], 'version'=>string]
     * @return array the mutated idsToRetrieve structure
     */
    public static function retrieveSignedMails(array $aArgs): array
    {
        $config  = $aArgs['config'];
        $version = $aArgs['version'];

        $aArgs['idsToRetrieve']['error'] = [$version => []];

        $built = self::buildClient($config);
        if (!empty($built['error'])) {
            foreach (array_keys($aArgs['idsToRetrieve'][$version] ?? []) as $resId) {
                $aArgs['idsToRetrieve']['error'][$version][$resId] = $built['error'];
                unset($aArgs['idsToRetrieve'][$version][$resId]);
            }
            return $aArgs['idsToRetrieve'];
        }
        $client       = $built['client'];
        $signedStates = self::states($config, 'signedStates', 'SIGNED,COMPLETED,FINISHED,VALIDATED,DONE');
        $refusedState = self::states($config, 'refusedStates', 'REFUSED,REJECTED,CANCELED,CANCELLED,EXPIRED');

        foreach (($aArgs['idsToRetrieve'][$version] ?? []) as $resId => $value) {
            $externalId = $value['external_id'] ?? null;
            if (empty($externalId)) {
                $aArgs['idsToRetrieve']['error'][$version][$resId] = 'Empty external_id';
                unset($aArgs['idsToRetrieve'][$version][$resId]);
                continue;
            }

            [$transactionId, $identifier] = array_pad(explode('/', $externalId, 2), 2, null);

            try {
                $info    = $client->getTransaction($transactionId);
                $infoObj = $info['object'] ?? $info;
                $status  = strtoupper((string)(
                    $infoObj['status'] ?? $info['status'] ?? $info['state'] ?? $info['transactionStatus'] ?? ''
                ));

                if (in_array($status, $signedStates, true)) {
                    if (empty($identifier)) {
                        throw new \RuntimeException('Missing document identifier for signed transaction ' . $transactionId);
                    }
                    $signedPdf = $client->downloadPdf($transactionId, $identifier);
                    $aArgs['idsToRetrieve'][$version][$resId]['status']      = 'validated';
                    $aArgs['idsToRetrieve'][$version][$resId]['format']      = 'pdf';
                    $aArgs['idsToRetrieve'][$version][$resId]['encodedFile'] = base64_encode($signedPdf);
                    $aArgs['idsToRetrieve'][$version][$resId]['notes'][]     = ['content' => 'Signé via NGSign (transaction ' . $transactionId . ')'];
                    self::updateTrackStatus($transactionId, 'SIGNED');
                } elseif (in_array($status, $refusedState, true)) {
                    $aArgs['idsToRetrieve'][$version][$resId]['status']  = 'refused';
                    $aArgs['idsToRetrieve'][$version][$resId]['notes'][] = ['content' => 'Refusé/annulé via NGSign (' . $status . ')'];
                    self::updateTrackStatus($transactionId, 'REFUSED');
                } else {
                    $aArgs['idsToRetrieve'][$version][$resId]['status'] = 'waiting';
                }
            } catch (\Throwable $e) {
                $aArgs['idsToRetrieve']['error'][$version][$resId] = 'NGSign retrieve error (' . $transactionId . '): ' . $e->getMessage();
                unset($aArgs['idsToRetrieve'][$version][$resId]);
            }
        }

        return $aArgs['idsToRetrieve'];
    }

    // =========================================================================
    // Internals
    // =========================================================================

    private static function buildClient(array $config): array
    {
        $url   = (string)($config['data']['url'] ?? '');
        $token = (string)($config['data']['token'] ?? '');
        if ($url === '' || $token === '' || $token === 'CHANGE_ME' || $token === '__NGSIGN_TOKEN__') {
            return ['error' => 'NGSign url/token not configured in remoteSignatoryBooks.xml'];
        }
        return ['client' => new NgsignClient($url, $token)];
    }

    private static function resolveSigner(int $resIdMaster): array
    {
        $signatory = DatabaseModel::select([
            'select' => ['item_id'],
            'table'  => ['listinstance'],
            'where'  => ['res_id = ?', 'item_mode = ?', 'process_date is null'],
            'data'   => [$resIdMaster, 'sign']
        ]);

        if (empty($signatory[0]['item_id'])) {
            return ['error' => 'No signatory (visa circuit step "sign") found for resource ' . $resIdMaster];
        }

        $user = UserModel::getById([
            'id'     => $signatory[0]['item_id'],
            'select' => ['firstname', 'lastname', 'mail', 'phone']
        ]);
        if (empty($user['mail'])) {
            return ['error' => 'The NGSign signatory user has no email address'];
        }

        return [
            'firstName'   => (string)($user['firstname'] ?? ''),
            'lastName'    => (string)($user['lastname'] ?? ''),
            'email'       => (string)$user['mail'],
            'phoneNumber' => (string)($user['phone'] ?? '')
        ];
    }

    private static function resolvePdfPath(int $resId, string $collId): ?string
    {
        $adr = ConvertPdfController::getConvertedPdfById(['resId' => $resId, 'collId' => $collId]);
        if (empty($adr['docserver_id']) || strtolower(pathinfo($adr['filename'] ?? '', PATHINFO_EXTENSION)) !== 'pdf') {
            return null;
        }
        $docserver = DocserverModel::getByDocserverId(['docserverId' => $adr['docserver_id'], 'select' => ['path_template']]);
        if (empty($docserver['path_template'])) {
            return null;
        }
        $path = $docserver['path_template'] . str_replace('#', '/', $adr['path']) . $adr['filename'];
        return is_file($path) ? $path : null;
    }

    /**
     * Upload the PDF to NGSign and launch the signature. Returns the external id "transactionId/identifier".
     */
    private static function pushDocument(NgsignClient $client, array $config, string $pdfPath, string $title, array $signer): array
    {
        try {
            $fileName = self::safeName($title);
            $base64   = base64_encode(file_get_contents($pdfPath));

            $upload = $client->uploadPdf($fileName, $base64);
            [$transactionId, $identifier] = self::extractUploadIds($upload);

            // choosePosition=true (default): the signer places the signature interactively
            // on the NGSign signing page, so no page/x/y are sent. Set it to false in the
            // config to fall back to the fixed defaultPage/defaultXAxis/defaultYAxis position.
            $chooseRaw      = strtolower(trim((string)($config['data']['choosePosition'] ?? 'true')));
            $choosePosition = !in_array($chooseRaw, ['0', 'false', 'no', 'off', ''], true);

            $docConfig = [
                'documentName'      => $fileName,
                'documentExtension' => 'pdf',
                'identifier'        => $identifier,
            ];
            if (!$choosePosition) {
                $docConfig['page']  = (int)($config['data']['defaultPage'] ?? 1);
                $docConfig['xAxis'] = (float)($config['data']['defaultXAxis'] ?? 81);
                $docConfig['yAxis'] = (float)($config['data']['defaultYAxis'] ?? 44.28125);
            }

            $sigConf = [[
                'signer'         => [
                    'firstName'   => $signer['firstName'],
                    'lastName'    => $signer['lastName'],
                    'email'       => $signer['email'],
                    'phoneNumber' => $signer['phoneNumber'],
                ],
                'sigType'        => (string)($config['data']['defaultSigType'] ?? 'CERTIFIED_TIMESTAMP'),
                'choosePosition' => $choosePosition,
                'docsConfigs'    => [$docConfig],
                'mode'           => (string)($config['data']['defaultMode'] ?? 'BY_MAIL'),
                'otp'            => (string)($config['data']['defaultOtp'] ?? 'NONE'),
            ]];

            $client->launch($transactionId, $sigConf);

            return [
                'externalId'    => $transactionId . '/' . $identifier,
                'transactionId' => $transactionId,
                'identifier'    => $identifier
            ];
        } catch (\Throwable $e) {
            return ['error' => 'NGSign send error: ' . $e->getMessage()];
        }
    }

    private static function extractUploadIds(array $response): array
    {
        // NGSign wraps the transaction in an "object" envelope:
        //   { "object": { "uuid": "...", "pdfs": [ { "identifier": "..." } ] } }
        $obj = $response['object'] ?? $response;

        $transactionId = $obj['uuid']
            ?? $obj['id']
            ?? $response['transactionId']
            ?? $response['id']
            ?? $response['transaction']['id']
            ?? $response[0]['transactionId']
            ?? null;

        $identifier = $obj['pdfs'][0]['identifier']
            ?? $obj['documents'][0]['identifier']
            ?? $response['identifier']
            ?? $response[0]['identifier']
            ?? $response['documents'][0]['identifier']
            ?? $response['pdfs'][0]['identifier']
            ?? $response['transaction']['pdfs'][0]['identifier']
            ?? null;

        if (empty($transactionId) || empty($identifier)) {
            throw new \RuntimeException('Unable to extract transactionId/identifier from NGSign upload response: ' . json_encode($response));
        }

        return [(string)$transactionId, (string)$identifier];
    }

    private static function states(array $config, string $key, string $default): array
    {
        $raw = (string)($config['data'][$key] ?? '');
        if ($raw === '') {
            $raw = $default;
        }
        return array_values(array_filter(array_map(
            static fn ($s) => strtoupper(trim($s)),
            explode(',', $raw)
        )));
    }

    private static function safeName(string $title): string
    {
        $name = preg_replace('/[^A-Za-z0-9_\- ]/', '', $title);
        $name = trim($name) !== '' ? trim($name) : 'document';
        return substr($name, 0, 120);
    }

    // --- Optional local tracking (best effort, never breaks the flow) ---------

    private static function track(int $resIdMaster, int $attachmentResId, array $pushed, array $signer): void
    {
        try {
            DatabaseModel::insert([
                'table'         => 'ngsign_transactions',
                'columnsValues' => [
                    'maarch_res_id'              => $resIdMaster,
                    'maarch_attachment_id'       => $attachmentResId,
                    'ngsign_transaction_id'      => $pushed['transactionId'],
                    'ngsign_document_identifier' => $pushed['identifier'],
                    'status'                     => 'SENT',
                    'signer_email'               => $signer['email'],
                    'signer_firstname'           => $signer['firstName'],
                    'signer_lastname'            => $signer['lastName']
                ]
            ]);
        } catch (\Throwable $e) {
            // tracking table is optional — ignore.
        }
    }

    private static function updateTrackStatus(string $transactionId, string $status): void
    {
        try {
            DatabaseModel::update([
                'table'   => 'ngsign_transactions',
                'set'     => ['status' => $status],
                'postSet' => ['updated_at' => 'now()'],
                'where'   => ['ngsign_transaction_id = ?'],
                'data'    => [$transactionId]
            ]);
        } catch (\Throwable $e) {
            // ignore.
        }
    }
}
