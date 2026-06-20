-- Atualiza whitelist de e-mails autorizados a serem administradores
CREATE OR REPLACE FUNCTION public.handle_new_user_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF lower(NEW.email) IN ('raionemachado20@gmail.com', 'bso.32.1988@gmail.com') THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'admin')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- Garante o trigger no auth.users (idempotente)
DROP TRIGGER IF EXISTS on_auth_user_created_admin ON auth.users;
CREATE TRIGGER on_auth_user_created_admin
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_admin();

-- Bloqueia INSERT direto em user_roles concedendo 'admin' a usuários fora da whitelist
CREATE OR REPLACE FUNCTION public.enforce_admin_whitelist()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NEW.role = 'admin' THEN
    SELECT lower(email) INTO v_email FROM auth.users WHERE id = NEW.user_id;
    IF v_email IS NULL OR v_email NOT IN ('raionemachado20@gmail.com', 'bso.32.1988@gmail.com') THEN
      RAISE EXCEPTION 'Acesso não autorizado: e-mail % não está na whitelist administrativa', COALESCE(v_email, NEW.user_id::text);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_admin_whitelist_trg ON public.user_roles;
CREATE TRIGGER enforce_admin_whitelist_trg
BEFORE INSERT OR UPDATE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.enforce_admin_whitelist();

-- Remove admin de qualquer usuário fora da whitelist
DELETE FROM public.user_roles
WHERE role = 'admin'
  AND user_id NOT IN (
    SELECT id FROM auth.users
    WHERE lower(email) IN ('raionemachado20@gmail.com', 'bso.32.1988@gmail.com')
  );