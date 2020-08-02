#!/usr/bin/env ruby
require 'pry'

dirname = ARGV.first
WORKING = '/home/ubuntu/working'

unless dirname && Dir.exist?(dirname)
  print "Usage: import.rb <directory name>\n\n"
  print "Ex: import.rb Brazil/Minas_Gerais/Novo_Lima\n\n"
  print "Directory names must begin with the country.\n"
  exit
end

#if false
#####################
# Generate CSV Files
#####################

print("Generating CSV files from directories\n")
system("./generate_csv.rb #{dirname}")
system("rm #{WORKING}/*.csv*")
system("cp ssda_*.csv #{WORKING}")


#####################
# Chunk CSV Files
#####################

print("Chunking CSV files\n")
Dir.glob(File.join(WORKING, '*.csv')).each do |file|
  total_lines = `wc -l #{file}`.to_i
  chunks = total_lines / 1000
  if chunks > 0
    0.upto(chunks).each do |chunk|
      outfile = "#{file}.offset.#{chunk}"
      system("head -1 #{file} > #{outfile}")
      offset = (chunk+1)*1000 + 1
      cmd = "head -#{offset} #{file} | tail -1000 >> #{outfile}"
#      p cmd
      system(cmd)
    end
  end
end

#end # if false

#########################
# Copy files/run imports
#########################

FILE_DEPENDENCIES = {
  "ssda_collection" => ['collection'],
  'ssda_volume' => ['volume'],
  'ssda_pages' => ['file', 'node', 'media']
}



DATA_DIR = "/var/www/html/drupal/web/modules/contrib/migrate_islandora_csv/data"
run_file=File.open("#{WORKING}/run.sh", "w")
log="#{WORKING}/run.log"
drush_log="#{WORKING}/drush.log"

print("Running migrations\n")
FILE_DEPENDENCIES.each_pair do |filename, migrations|
  # first, do we need to chunk?
  files = Dir.glob(File.join(WORKING, "#{filename}*offset*"))
  if files.count < 1
    files = Dir.glob(File.join(WORKING, "#{filename}.csv"))
  end

  files.sort.each do |file|
    target = File.join(DATA_DIR, "#{filename}.csv")
    cmd = "cp #{file} #{target}\n"
    run_file.print "echo '#{file}' >> #{log}\n"
    run_file.print "date >> #{log}\n"
    run_file.print cmd
# Was commented out for last Brazil run 2020-07-02
#    system(cmd)

    migrations.each do |migration|
      cmd = "cd #{DATA_DIR}; drush -y --userid=1 migrate:import #{migration} --uri=http://52.202.64.56:80 >> #{drush_log} 2>&1 \n"
      run_file.print "echo '#{migration}' >> #{log}\n"
      run_file.print "date >> #{log}\n"
      run_file.print "echo '#{migration}' >> #{drush_log}\n"
      run_file.print "date >> #{drush_log}\n"
      run_file.print cmd
 #     system(cmd)
    end    

  end 

end

run_file.close
