BEGIN;

CREATE TABLE biz_001.communication_logs (
  id                    UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id           TEXT         NOT NULL DEFAULT 'biz_001',
  recipient_entity_id   UUID         NOT NULL,
  sender_agent          TEXT         NOT NULL,
  channel               TEXT         NOT NULL,
  language              TEXT         NOT NULL,
  category              TEXT         NOT NULL,
  subject               TEXT         NULL,
  message_content       TEXT         NOT NULL,
  sent_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  delivery_status       TEXT         NOT NULL DEFAULT 'pending',
  failure_reason        TEXT         NULL,
  metadata              JSONB        NULL DEFAULT '{}'::jsonb,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT communication_logs_pkey PRIMARY KEY (id),
  CONSTRAINT communication_logs_recipient_fk 
    FOREIGN KEY (recipient_entity_id) 
    REFERENCES biz_001.entities(id),
  CONSTRAINT communication_logs_channel_check 
    CHECK (channel IN ('whatsapp', 'sms', 'email', 'call')),
  CONSTRAINT communication_logs_language_check 
    CHECK (language IN ('english', 'telugu', 'hindi')),
  CONSTRAINT communication_logs_status_check 
    CHECK (delivery_status IN ('pending', 'sent', 'delivered', 'failed')),
  CONSTRAINT communication_logs_category_check 
    CHECK (category IN ('academic', 'attendance', 'admin', 'marketing', 
                        'fee_reminder', 'admission', 'event'))
);

-- Index: lookup messages by recipient, newest first
CREATE INDEX comm_logs_recipient_sent_idx 
  ON biz_001.communication_logs(recipient_entity_id, sent_at DESC);

-- Index: lookup messages by agent, newest first
CREATE INDEX comm_logs_sender_sent_idx 
  ON biz_001.communication_logs(sender_agent, sent_at DESC);

-- Partial index: only failed messages (small, used for retry/analysis)
CREATE INDEX comm_logs_failed_idx 
  ON biz_001.communication_logs(delivery_status) 
  WHERE delivery_status = 'failed';

-- updated_at trigger (reuses function created in migration 010)
CREATE TRIGGER comm_logs_set_updated_at
  BEFORE UPDATE ON biz_001.communication_logs
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

-- Enable RLS (real policies in migration 017)
ALTER TABLE biz_001.communication_logs ENABLE ROW LEVEL SECURITY;

COMMIT;
