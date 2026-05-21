CREATE OR REPLACE FUNCTION provisionar_usuario()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_nome  TEXT;
  v_papel papel_usuario;
BEGIN
  v_nome  := COALESCE(NEW.raw_user_meta_data ->> 'nome',  NEW.email, 'Sem nome');
  v_papel := COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'papel', '')::papel_usuario,
                      'aluno');

  INSERT INTO public.usuarios (id, nome, papel)
  VALUES (NEW.id, v_nome, v_papel)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auth_user_criado
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION provisionar_usuario();

CREATE OR REPLACE FUNCTION valida_admin_escola()
RETURNS TRIGGER AS $$
DECLARE
  v_papel papel_usuario;
BEGIN
  SELECT papel INTO v_papel FROM usuarios WHERE id = NEW.admin_id;

  IF v_papel IS NULL THEN
    RAISE EXCEPTION 'Usuário % não encontrado em usuarios', NEW.admin_id;
  ELSIF v_papel NOT IN ('admin_escola', 'admin_global') THEN
    RAISE EXCEPTION 'admin_id % precisa ter papel admin_escola (atual: %)',
                    NEW.admin_id, v_papel;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_escolas_valida_admin
  BEFORE INSERT OR UPDATE OF admin_id ON escolas
  FOR EACH ROW EXECUTE FUNCTION valida_admin_escola();

CREATE OR REPLACE FUNCTION atualiza_contadores_sessao()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE sessoes
       SET total_questoes = total_questoes + 1,
           acertos        = acertos + CASE WHEN NEW.acertou THEN 1 ELSE 0 END
     WHERE id = NEW.sessao_id;

  ELSIF TG_OP = 'UPDATE' AND OLD.acertou IS DISTINCT FROM NEW.acertou THEN
    UPDATE sessoes
       SET acertos = acertos
                     + CASE WHEN NEW.acertou THEN 1 ELSE 0 END
                     - CASE WHEN OLD.acertou THEN 1 ELSE 0 END
     WHERE id = NEW.sessao_id;

  ELSIF TG_OP = 'DELETE' THEN
    UPDATE sessoes
       SET total_questoes = total_questoes - 1,
           acertos        = acertos - CASE WHEN OLD.acertou THEN 1 ELSE 0 END
     WHERE id = OLD.sessao_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_respostas_contadores
  AFTER INSERT OR UPDATE OF acertou OR DELETE ON respostas
  FOR EACH ROW EXECUTE FUNCTION atualiza_contadores_sessao();
