Sequel.migration do
  change { add_column :reports, :ip, :inet }
end
