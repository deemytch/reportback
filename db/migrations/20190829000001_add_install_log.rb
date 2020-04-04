Sequel.migration do
  change { add_column :reports, :install_log, String }
end
