-- Questions can target one gender or both.
ALTER TABLE form_question
    ADD COLUMN visible_for_gender varchar(10) NOT NULL DEFAULT 'BOTH';

ALTER TABLE form_question
    ADD CONSTRAINT chk_form_question_visible_for_gender
        CHECK (visible_for_gender IN ('MALE', 'FEMALE', 'BOTH'));
