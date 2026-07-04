CREATE TABLE IF NOT EXISTS ngsign_transactions (
    id SERIAL PRIMARY KEY,
    maarch_res_id INTEGER NOT NULL,
    maarch_attachment_id INTEGER NULL,
    ngsign_transaction_id VARCHAR(100) NOT NULL,
    ngsign_document_identifier VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'SENT',
    signer_email VARCHAR(255),
    signer_firstname VARCHAR(100),
    signer_lastname VARCHAR(100),
    last_error TEXT,
    signed_file_path TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ngsign_transactions_res_id ON ngsign_transactions(maarch_res_id);
CREATE INDEX IF NOT EXISTS idx_ngsign_transactions_status ON ngsign_transactions(status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ngsign_transaction_doc ON ngsign_transactions(ngsign_transaction_id, ngsign_document_identifier);
