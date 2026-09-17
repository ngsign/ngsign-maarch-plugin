<?php

declare(strict_types=1);

/*
 * Applies the three Option-B changes documented in docs/PATCHES.md.
 * Each replacement has an explicit guard so an incompatible Maarch release
 * stops the Docker build instead of silently producing a partial connector.
 */

if ($argc !== 2) {
    fwrite(STDERR, "Usage: apply-ngsign-patches.php <maarch-root>\n");
    exit(2);
}

$root = rtrim($argv[1], '/');

/** @param array<string, string> $replacements */
function replaceRequired(string $path, array $replacements): void
{
    $content = file_get_contents($path);
    if ($content === false) {
        throw new RuntimeException("Cannot read {$path}");
    }

    foreach ($replacements as $before => $after) {
        if (str_contains($content, $after)) {
            continue;
        }
        if (!str_contains($content, $before)) {
            throw new RuntimeException("Expected Maarch 2301 code was not found in {$path}");
        }
        $content = str_replace($before, $after, $content);
    }

    if (file_put_contents($path, $content) === false) {
        throw new RuntimeException("Cannot write {$path}");
    }
}

function contexts(string $content, string $needle): string
{
    $offset = 0;
    $matches = [];
    while (($position = strpos($content, $needle, $offset)) !== false && count($matches) < 3) {
        $matches[] = preg_replace('/\s+/', ' ', substr($content, max(0, $position - 220), 600));
        $offset = $position + strlen($needle);
    }
    return implode(' | ', $matches);
}

try {
    replaceRequired(
        "{$root}/src/app/action/controllers/ExternalSignatoryBookTrait.php",
        [
            "} elseif (\$config['id'] == 'iParapheur') {" => <<<'PHP'
} elseif ($config['id'] == 'ngsign') {
    $sentInfo = \ExternalSignatoryBook\ngsign\controllers\NgsignController::sendDatas([
        'config'      => $config,
        'resIdMaster' => $args['resId']
    ]);
} elseif ($config['id'] == 'iParapheur') {
PHP,
        ]
    );

    replaceRequired(
        "{$root}/src/app/action/controllers/PreProcessActionController.php",
        [
            "['maarchParapheur', 'fastParapheur', 'iParapheur', 'ixbus']" =>
                "['maarchParapheur', 'fastParapheur', 'iParapheur', 'ixbus', 'ngsign']",
        ]
    );

    $batch = "{$root}/bin/signatureBook/process_mailsFromSignatoryBook.php";
    replaceRequired(
        $batch,
        [
            "['maarchParapheur', 'xParaph', 'fastParapheur', 'iParapheur', 'ixbus']" =>
                "['maarchParapheur', 'xParaph', 'fastParapheur', 'iParapheur', 'ixbus', 'ngsign']",
        ]
    );

    $content = file_get_contents($batch);
    if ($content === false) {
        throw new RuntimeException("Cannot read {$batch}");
    }

    $dispatches = [
        // These are the first dispatch branches in the Maarch Courrier 2301.1.5
        // runtime image. Insert NGSign before them; no existing provider changes.
        'retrievedMails' => [
            'version' => 'noVersion',
            'anchor'  => "if (\$configRemoteSignatoryBook['id'] == 'ixbus') {",
        ],
        'retrievedLetterboxMails' => [
            'version' => 'resLetterbox',
            'anchor'  => "if (\$configRemoteSignatoryBook['id'] == 'maarchParapheur') {",
        ],
    ];
    foreach ($dispatches as $variable => $dispatch) {
        $resultVariable = '$' . $variable;
        if (str_contains($content, "{$resultVariable} = \\ExternalSignatoryBook\\ngsign\\controllers\\NgsignController::retrieveSignedMails")) {
            continue;
        }

        $anchor = $dispatch['anchor'];
        $version = $dispatch['version'];
        $replacement = "if (\$configRemoteSignatoryBook['id'] == 'ngsign') {\n"
            . "    {$resultVariable} = \\ExternalSignatoryBook\\ngsign\\controllers\\NgsignController::retrieveSignedMails(['config' => \$configRemoteSignatoryBook, 'idsToRetrieve' => \$idsToRetrieve, 'version' => '{$version}']);\n"
            . '} elseif ' . substr($anchor, 3);
        $updated = str_replace($anchor, $replacement, $content, $count);
        if ($count !== 1) {
            throw new RuntimeException(
                "Could not find the {$variable} dispatch anchor in {$batch}. "
                . 'Batch context: ' . contexts($content, $resultVariable)
            );
        }
        $content = $updated;
    }

    if (file_put_contents($batch, $content) === false) {
        throw new RuntimeException("Cannot write {$batch}");
    }
} catch (Throwable $exception) {
    fwrite(STDERR, "NGSign patch error: {$exception->getMessage()}\n");
    exit(1);
}
