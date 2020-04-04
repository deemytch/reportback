Sequel.migration do
  change { add_column :reports, :cert, String }
end
