# Выполняемые в данный момент команды
Sequel.migration do

  up do
    run "CREATE TYPE boxtype AS ENUM ('tableau', 'kiosk', 'server', 'other');"
    create_table :reports do
      primary_key :id, type: :BIGINT
      column :region, String, size: 64, null: false, index: true
      column :descr, String
      column :kindof, :boxtype, index: true
      
      column :hardware, :jsonb
      column :authkeys, :jsonb

      column :created_at, DateTime, null: false, index: true, default: Sequel.lit("now()")
      column :updated_at, DateTime, null: false, index: true, default: Sequel.lit("now()")
    end
    run <<~EUP
      DO $$
      BEGIN
        --triggers
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'report_update_timestamp') THEN
          CREATE TRIGGER report_update_timestamp 
            BEFORE INSERT OR UPDATE ON reports
            FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
        END IF;
      END $$;
    EUP
  end
  
  down { run 'DROP TABLE reports CASCADE;' }

end
