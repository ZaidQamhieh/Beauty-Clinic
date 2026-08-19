-- The definition is data, not code: an inactive question remains here so its
-- historical patient answers are never lost.
CREATE TABLE form_question (
                               id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                               form_key varchar(80) NOT NULL,
                               field_key varchar(80) NOT NULL,
                               label varchar(255) NOT NULL,
                               help_text text,
                               field_type varchar(30) NOT NULL CHECK (field_type IN ('BOOLEAN','SINGLE_SELECT','MULTI_SELECT')),
                               required boolean NOT NULL DEFAULT false,
                               display_order integer NOT NULL,
                               active boolean NOT NULL DEFAULT true,
                               created_at timestamptz NOT NULL DEFAULT now(),
                               updated_at timestamptz NOT NULL DEFAULT now(),
                               UNIQUE (form_key, field_key)
);
CREATE INDEX idx_form_question_visible ON form_question(form_key, display_order) WHERE active;

CREATE TABLE form_question_option (
                                      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                                      question_id uuid NOT NULL REFERENCES form_question(id) ON DELETE RESTRICT,
                                      value varchar(100) NOT NULL,
                                      label varchar(255) NOT NULL,
                                      display_order integer NOT NULL,
                                      active boolean NOT NULL DEFAULT true,
                                      UNIQUE (question_id, value)
);
CREATE INDEX idx_form_question_option_visible ON form_question_option(question_id, display_order) WHERE active;

-- One current answer document per patient/form. JSONB retains answers belonging
-- to inactive questions when a clinic removes a question from the UI.
CREATE TABLE patient_form_response (
                                       patient_user_id uuid NOT NULL REFERENCES patient_profile(user_id) ON DELETE RESTRICT,
                                       form_key varchar(80) NOT NULL,
                                       answers jsonb NOT NULL DEFAULT '{}'::jsonb,
                                       updated_at timestamptz NOT NULL DEFAULT now(),
                                       PRIMARY KEY (patient_user_id, form_key)
);

CREATE TRIGGER trg_form_question_updated BEFORE UPDATE ON form_question
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_patient_form_response_updated BEFORE UPDATE ON patient_form_response
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO form_question (form_key, field_key, label, field_type, required, display_order) VALUES
                                                                                                ('clinical-intake','pregnantBreastfeeding','Pregnant or breastfeeding','BOOLEAN',true,10),
                                                                                                ('clinical-intake','skinType','Skin type','SINGLE_SELECT',true,20),
                                                                                                ('clinical-intake','smokingStatus','Smoking status','SINGLE_SELECT',false,30),
                                                                                                ('clinical-intake','allergies','Allergies','MULTI_SELECT',false,40),
                                                                                                ('clinical-intake','medications','Current medications','MULTI_SELECT',false,50),
                                                                                                ('clinical-intake','chronicConditions','Chronic conditions','MULTI_SELECT',false,60);

INSERT INTO form_question_option (question_id, value, label, display_order)
SELECT q.id, v.value, v.label, v.position FROM form_question q
                                                   JOIN (VALUES
                                                             ('skinType','NORMAL','Normal',10),('skinType','DRY','Dry',20),('skinType','OILY','Oily',30),('skinType','COMBINATION','Combination',40),('skinType','SENSITIVE','Sensitive',50),
                                                             ('smokingStatus','NEVER','Never',10),('smokingStatus','FORMER','Former',20),('smokingStatus','CURRENT','Current',30),
                                                             ('allergies','NUTS','Nuts',10),('allergies','LATEX','Latex',20),('allergies','PENICILLIN','Penicillin',30),('allergies','SULFA','Sulfa',40),
                                                             ('medications','ISOTRETINOIN','Isotretinoin',10),('medications','ANTICOAGULANTS','Anticoagulants',20),
                                                             ('chronicConditions','DIABETES','Diabetes',10),('chronicConditions','HYPERTENSION','Hypertension',20)
) AS v(field_key,value,label,position) ON v.field_key=q.field_key WHERE q.form_key='clinical-intake';
