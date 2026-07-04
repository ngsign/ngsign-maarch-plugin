<?php

/**
 * Copyright (C) 2026 NG Technologies.
 * Part of the NGSign connector for Maarch Courrier.
 * Licensed under the GNU General Public License v3.0 (see LICENSE).
 */

namespace ExternalSignatoryBook\ngsign\Infrastructure;

use RuntimeException;

class NgsignClient
{
    private string $baseUrl;
    private string $token;

    public function __construct(string $baseUrl, string $token)
    {
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->token = $token;
    }

    public function uploadPdf(string $fileName, string $base64Pdf): array
    {
        $payload = [[
            'fileName' => $fileName,
            'fileExtension' => 'pdf',
            'fileBase64' => $base64Pdf,
        ]];

        return $this->request('POST', '/server/protected/transaction/pdfs', $payload);
    }

    public function launch(string $transactionId, array $sigConf): array
    {
        return $this->request('POST', "/server/protected/transaction/{$transactionId}/launch", [
            'sigConf' => $sigConf,
        ]);
    }

    public function getTransaction(string $transactionId): array
    {
        return $this->request('GET', "/server/any/transaction/{$transactionId}");
    }

    public function downloadPdf(string $transactionId, string $identifier): string
    {
        return $this->requestRaw('GET', "/server/any/transaction/{$transactionId}/pdfs/{$identifier}");
    }

    private function request(string $method, string $path, ?array $payload = null): array
    {
        $raw = $this->requestRaw($method, $path, $payload);
        $decoded = json_decode($raw, true);

        if ($decoded === null && json_last_error() !== JSON_ERROR_NONE) {
            throw new RuntimeException('NGSign returned a non-JSON response: ' . substr($raw, 0, 300));
        }

        return $decoded;
    }

    private function requestRaw(string $method, string $path, ?array $payload = null): string
    {
        $ch = curl_init($this->baseUrl . $path);
        $headers = [
            'Authorization: Bearer ' . $this->token,
        ];

        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        // The NGSign sandbox is slow: uploads can take 80s+. Keep generous timeouts.
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 30);
        curl_setopt($ch, CURLOPT_TIMEOUT, 240);

        if ($payload !== null) {
            $headers[] = 'Content-Type: application/json';
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        }

        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        $response = curl_exec($ch);
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($response === false || $httpCode < 200 || $httpCode >= 300) {
            throw new RuntimeException("NGSign HTTP {$httpCode}: {$error} " . substr((string) $response, 0, 500));
        }

        return (string) $response;
    }
}
