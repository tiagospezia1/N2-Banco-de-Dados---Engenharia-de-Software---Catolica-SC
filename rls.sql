CREATE OR REPLACE FUNCTION papel_atual()
RETURNS papel_usuario
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT papel FROM usuarios WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION escolas_que_administro()
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM escolas WHERE admin_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION alunos_das_minhas_escolas()
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.aluno_id
    FROM matriculas m
   WHERE m.escola_id IN (SELECT id FROM escolas WHERE admin_id = auth.uid());
$$;

ALTER TABLE usuarios   ENABLE ROW LEVEL SECURITY;
ALTER TABLE enderecos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE escolas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE matriculas ENABLE ROW LEVEL SECURITY;
ALTER TABLE questoes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessoes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE respostas  ENABLE ROW LEVEL SECURITY;

CREATE POLICY usuarios_select ON usuarios FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR papel_atual() = 'admin_global'
    OR (papel_atual() = 'admin_escola'
        AND id IN (SELECT alunos_das_minhas_escolas()))
  );

CREATE POLICY usuarios_update ON usuarios FOR UPDATE TO authenticated
  USING (id = auth.uid() OR papel_atual() = 'admin_global')
  WITH CHECK (id = auth.uid() OR papel_atual() = 'admin_global');

CREATE POLICY enderecos_select ON enderecos FOR SELECT TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR id IN (SELECT endereco_id FROM usuarios WHERE id = auth.uid())
    OR id IN (SELECT endereco_id FROM escolas  WHERE id IN (SELECT escolas_que_administro()))
  );

CREATE POLICY enderecos_modify ON enderecos FOR ALL TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR id IN (SELECT endereco_id FROM usuarios WHERE id = auth.uid())
  )
  WITH CHECK (
    papel_atual() IN ('admin_global', 'admin_escola', 'aluno')
  );

CREATE POLICY escolas_select ON escolas FOR SELECT TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR admin_id   = auth.uid()
    OR id IN (SELECT escola_id FROM matriculas WHERE aluno_id = auth.uid())
  );

CREATE POLICY escolas_modify ON escolas FOR ALL TO authenticated
  USING (papel_atual() = 'admin_global' OR admin_id = auth.uid())
  WITH CHECK (papel_atual() = 'admin_global' OR admin_id = auth.uid());

CREATE POLICY matriculas_select ON matriculas FOR SELECT TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR aluno_id  = auth.uid()
    OR escola_id IN (SELECT escolas_que_administro())
  );

CREATE POLICY matriculas_modify ON matriculas FOR ALL TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR escola_id IN (SELECT escolas_que_administro())
  )
  WITH CHECK (
    papel_atual() = 'admin_global'
    OR escola_id IN (SELECT escolas_que_administro())
  );

CREATE POLICY questoes_select ON questoes FOR SELECT TO authenticated
  USING (true);

CREATE POLICY questoes_modify ON questoes FOR ALL TO authenticated
  USING (papel_atual() = 'admin_global')
  WITH CHECK (papel_atual() = 'admin_global');

CREATE POLICY sessoes_select ON sessoes FOR SELECT TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR aluno_id = auth.uid()
    OR aluno_id IN (SELECT alunos_das_minhas_escolas())
  );

CREATE POLICY sessoes_modify ON sessoes FOR ALL TO authenticated
  USING (aluno_id = auth.uid() OR papel_atual() = 'admin_global')
  WITH CHECK (aluno_id = auth.uid() OR papel_atual() = 'admin_global');

CREATE POLICY respostas_select ON respostas FOR SELECT TO authenticated
  USING (
    papel_atual() = 'admin_global'
    OR sessao_id IN (SELECT id FROM sessoes WHERE aluno_id = auth.uid())
    OR sessao_id IN (SELECT id FROM sessoes
                      WHERE aluno_id IN (SELECT alunos_das_minhas_escolas()))
  );

CREATE POLICY respostas_modify ON respostas FOR ALL TO authenticated
  USING (
    sessao_id IN (SELECT id FROM sessoes WHERE aluno_id = auth.uid())
    OR papel_atual() = 'admin_global'
  )
  WITH CHECK (
    sessao_id IN (SELECT id FROM sessoes WHERE aluno_id = auth.uid())
    OR papel_atual() = 'admin_global'
  );

1:1 com auth.users. Não armazena senha.';
default aluno.';

único por par.';

única por par.';
