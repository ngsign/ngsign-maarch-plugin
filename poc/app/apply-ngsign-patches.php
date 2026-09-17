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

    $patterns = [
        'retrievedMails' => 'noVersion',
        'retrievedLetterboxMails' => 'resLetterbox',
    ];
    foreach ($patterns as $variable => $version) {
        $resultVariable = '$' . $variable;
        if (str_contains($content, "{$resultVariable} = \\ExternalSignatoryBook\\ngsign\\controllers\\NgsignController::retrieveSignedMails")) {
            continue;
        }

        // Depending on the Maarch 2301 minor, iParapheur can be the first
        // branch (`if`) or a later branch (`} elseif`) in the dispatch chain.
        $pattern = "~((?:if|} elseif) \(\$configRemoteSignatoryBook\['id'\] == 'iParapheur'\) \{\s*"
            . preg_quote($resultVariable, '~') . " = .*?;\s*})~s";
        $replacement = '$1' . " elseif (\$configRemoteSignatoryBook['id'] == 'ngsign') {\n"
            . "    {$resultVariable} = \\ExternalSignatoryBook\\ngsign\\controllers\\NgsignController::retrieveSignedMails(['config' => \$configRemoteSignatoryBook, 'idsToRetrieve' => \$idsToRetrieve, 'version' => '{$version}']);\n"
            . '}';
        $updated = preg_replace($pattern, $replacement, $content, 1, $count);
        if ($updated === null || $count !== 1) {
            throw new RuntimeException("Could not add NGSign {$variable} dispatch in {$batch}");
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
