CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE papel_usuario AS ENUM ('aluno', 'admin_escola', 'admin_global');
CREATE TYPE status_sessao  AS ENUM ('em_andamento', 'concluida');

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE enderecos (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  cep           VARCHAR(8)   NOT NULL CHECK (cep ~ '^[0-9]{8}$'),
  logradouro    VARCHAR(150) NOT NULL,
  numero        VARCHAR(20)  NOT NULL,
  complemento   VARCHAR(100),
  bairro        VARCHAR(100) NOT NULL,
  cidade        VARCHAR(100) NOT NULL,
  uf            CHAR(2)      NOT NULL CHECK (uf ~ '^[A-Z]{2}$'),
  pais          CHAR(2)      NOT NULL DEFAULT 'BR',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_enderecos_cep    ON enderecos (cep);
CREATE INDEX idx_enderecos_cidade ON enderecos (cidade, uf);

CREATE TRIGGER trg_enderecos_updated
  BEFORE UPDATE ON enderecos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE usuarios (
  id           UUID            PRIMARY KEY
                               REFERENCES auth.users(id) ON DELETE CASCADE,
  nome         VARCHAR(150)    NOT NULL CHECK (length(btrim(nome)) > 0),
  papel        papel_usuario   NOT NULL DEFAULT 'aluno',
  endereco_id  UUID            REFERENCES enderecos(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ     NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE INDEX idx_usuarios_papel       ON usuarios (papel);
CREATE INDEX idx_usuarios_endereco_id ON usuarios (endereco_id);

CREATE TRIGGER trg_usuarios_updated
  BEFORE UPDATE ON usuarios
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE escolas (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nome         VARCHAR(150) NOT NULL,
  cnpj         VARCHAR(14)  NOT NULL UNIQUE CHECK (cnpj ~ '^[0-9]{14}$'),
  admin_id     UUID         NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
  endereco_id  UUID                  REFERENCES enderecos(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_escolas_admin_id    ON escolas (admin_id);
CREATE INDEX idx_escolas_endereco_id ON escolas (endereco_id);

CREATE TRIGGER trg_escolas_updated
  BEFORE UPDATE ON escolas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE matriculas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  aluno_id        UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  escola_id       UUID        NOT NULL REFERENCES escolas(id)  ON DELETE CASCADE,
  matriculado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (aluno_id, escola_id)
);

CREATE INDEX idx_matriculas_escola_id ON matriculas (escola_id);

CREATE TABLE questoes (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo        BIGSERIAL   UNIQUE,
  area          VARCHAR(50),
  enunciado     JSONB       NOT NULL,
  alternativas  JSONB       NOT NULL,
  gabarito      SMALLINT    NOT NULL CHECK (gabarito BETWEEN 1 AND 5),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_questoes_area         ON questoes (area);

CREATE INDEX idx_questoes_enunciado    ON questoes USING GIN (enunciado    jsonb_path_ops);
CREATE INDEX idx_questoes_alternativas ON questoes USING GIN (alternativas jsonb_path_ops);

CREATE TRIGGER trg_questoes_updated
  BEFORE UPDATE ON questoes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE sessoes (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  aluno_id        UUID          NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  iniciada_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  finalizada_em   TIMESTAMPTZ,
  status          status_sessao NOT NULL DEFAULT 'em_andamento',
  total_questoes  INTEGER       NOT NULL DEFAULT 0 CHECK (total_questoes >= 0),
  acertos         INTEGER       NOT NULL DEFAULT 0 CHECK (acertos >= 0),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT chk_sessao_acertos_validos
    CHECK (acertos <= total_questoes),

  CONSTRAINT chk_sessao_status_consistente
    CHECK (
      (status = 'em_andamento' AND finalizada_em IS NULL)
      OR
      (status = 'concluida'    AND finalizada_em IS NOT NULL
                               AND finalizada_em >= iniciada_em)
    )
);

CREATE INDEX idx_sessoes_aluno_id ON sessoes (aluno_id);
CREATE INDEX idx_sessoes_status   ON sessoes (status);

CREATE INDEX idx_sessoes_aluno_iniciada ON sessoes (aluno_id, iniciada_em DESC);

CREATE TRIGGER trg_sessoes_updated
  BEFORE UPDATE ON sessoes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE respostas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sessao_id       UUID        NOT NULL REFERENCES sessoes(id)  ON DELETE CASCADE,
  questao_id      UUID        NOT NULL REFERENCES questoes(id) ON DELETE CASCADE,
  alternativa     SMALLINT    NOT NULL CHECK (alternativa BETWEEN 1 AND 5),
  acertou         BOOLEAN     NOT NULL,
  respondida_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sessao_id, questao_id)
);

CREATE INDEX idx_respostas_questao_id ON respostas (questao_id);
