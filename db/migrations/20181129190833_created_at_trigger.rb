Sequel.migration do
  up do
    run <<~ESTOREDPROC
    CREATE OR REPLACE FUNCTION insert_timestamp() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
    BEGIN
      IF NEW.created_at IS NULL THEN
        NEW.created_at := now();
      END IF;
      RETURN NEW;
    END $$;

    CREATE OR REPLACE FUNCTION update_timestamp() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
    BEGIN
      IF NEW.updated_at IS NULL THEN
        NEW.updated_at := now();
      END IF;
      RETURN NEW;
    END $$;
    ESTOREDPROC
  end
  down { run 'DROP FUNCTION IF EXISTS insert_timestamp(); DROP FUNCTION IF EXISTS update_timestamp();' }
end
