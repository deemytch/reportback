Sequel.migration do
  up { run "ALTER TABLE reports ADD CONSTRAINT unique_cert UNIQUE ( cert )" }
  down { run "ALTER TABLE reports DROP CONSTRAINT unique_cert" }
end
