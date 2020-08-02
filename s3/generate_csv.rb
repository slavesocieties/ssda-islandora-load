#!/usr/bin/env ruby

require 'nokogiri'
require 'pry'
require 'csv'

FILE_ROOT = '/home/ubuntu/s3/test_batch'
S3_ROOT = 'https://static-assets.slavesocieties.org/'


dirname = ARGV.first

unless dirname && Dir.exist?(dirname)
  print "Usage: generate_csv.rb <directory name>\n\n"
  print "Ex: generate_csv Brazil/Minas_Gerais/Novo_Lima\n\n"
  print "Directory names must begin with the country.\n"
  exit
end

def ingest_volume_dir(path, volume_csv, page_csv)
  ingest_volume_metadata(path, volume_csv, page_csv)
  check_or_create_jpg_derivatives(path)
  ingest_volume_pages(path, volume_csv, page_csv)
end


# ingest a volume's metadata
def ingest_volume_metadata(path, volume_csv, page_csv)
  doc = File.open(File.join(path, 'Metadata', 'DC.xml')) { |f| Nokogiri::XML(f) }

  coverage = (doc.search('coverage')+doc.search('//dc:coverage')).to_a.map{|e| e.text}
  pair = coverage.detect{|e| e.match(/\d\d/)}
  if pair
    lat,lng = pair.split(/, ?/)
  else
    lat = nil
    lng = nil
  end

  subject = (doc.search('subject')+doc.search('//dc:subject')).to_a.map{|e| e.text}.join("|")
  subject.gsub!(/\s*--\s*/, "|")
  
  doc_type = (doc.search('type')+doc.search('//dc:type')).to_a.map{|e| e.text}.reject{|e| "Text"==e}.join("|")

  description = (doc.search('description')+doc.search('//dc:description')).to_a.map{|e| e.text}.join("|").gsub("\n","|")
 
  volume_csv << [
    File.dirname(path),   # collection key
    File.basename(path), 
    (doc.search('title')+doc.search('//dc:title')).to_a.map{|e| e.text}.join("|"), 
    (doc.search('creator')+doc.search('//dc:creator')).to_a.map{|e| e.text}.join("|"), 
    subject, 
    description,
    (doc.search('publisher')+doc.search('//dc:publisher')).to_a.map{|e| e.text}.join("|"),
    (doc.search('contributor')+doc.search('//dc:contributor')).to_a.map{|e| e.text}.join("|"),
    (doc.search('source')+doc.search('//dc:source')).to_a.map{|e| e.text}.join("|"),
    (doc.search('identifier')+doc.search('//dc:identifier')).to_a.map{|e| e.text}.join("|"),
    (doc.search('date')+doc.search('//dc:date')).to_a.map{|e| e.text}.join("|"),
    doc_type,
    (doc.search('language')+doc.search('//dc:language')).to_a.map{|e| e.text}.join("|"),
    (doc.search('coverage')+doc.search('//dc:coverage')).to_a.map{|e| e.text}.join("|"),
    (doc.search('rights')+doc.search('//dc:rights')).to_a.map{|e| e.text}.join("|"),
    lat,
    lng,
    File.dirname(path).gsub("_"," "),
    (doc.search('format')+doc.search('//dc:format')).to_a.map{|e| e.text}.join("|"),
  ]
end

# ingest a volume's pages
def ingest_volume_pages(path, volume_csv, page_csv)
  # create derivatives if they do not exist TODO

  Dir.glob(File.join(path, "JPG", "*")).sort.each_with_index do |filename,i|
    title = File.basename(filename).sub(File.extname(filename),'')
    page_csv << [
      File.basename(path), 
      i, 
      File.join(S3_ROOT, filename), 
      title, 
      title
    ]
  end
end

def check_or_create_jpg_derivatives(path)
  unless Dir.exist?(File.join(path,'JPG'))
    Dir.mkdir(File.join(path,'JPG'))
    Dir.glob(File.join(path,'TIF','*.[Tt][Ii][Ff]*')).each do |tiff|
      outfile = tiff.sub('TIF','JPG').sub(/\.[Tt][Ii][Ff]/, '.jpg')
      system("convert -strip -interlace Plane -gaussian-blur 0.05 -quality 85% #{tiff} #{outfile}")
    end
  end
end


def process_tree(path, collection_csv, volume_csv, page_csv)
  ls = Dir.glob(File.join(path, "*"))
  ls.each do |path|
    if Dir.exist? path # ignore random files
      # if we are a volume directory, ingest the volume
      if File.exist?(File.join(path, 'Metadata', 'DC.xml'))
        ingest_volume_dir(path, volume_csv, page_csv)
      else
        # if we are a branch directory, add the directory to the collections and process the children
        collection_csv << [path.sub(/\/$/,''), File.dirname(path), File.basename(path).gsub("_"," ")]
        process_tree(path, collection_csv, volume_csv, page_csv) #recurse
     end 
    end 
  end

end





# Broad outline
# Given a path USA/Texas/Austin, we want to make sure we have collection entries for the parents, USA and USA/Texas, then recurse through subdirectories building collection, volume, and file entries

# First, open all CSV files and add headers


collection_csv = CSV.open("ssda_collection.csv", "wb")
collection_csv << [
  "collection_key", 
  "parent_collection_key", 
  "title"
]

volume_csv = CSV.open("ssda_volume.csv", "wb")
volume_csv << [
  "collection_key",
  "volume_key", 
  "title", 
  "creator",
  "subject",
  "description",
  "publisher",    
  "contributor",    
  "source",    
  "identifier",    
  "date",    
  "type",    
  "language",    
  "coverage",    
  "rights",
  "coordinates_lat",
  "coordinates_lng",
  "geographic_subject",
  "format"
]

page_csv = CSV.open("ssda_pages.csv", "wb")
page_csv << [
  "volume_key",
  "weight",
  "file",
  "title",
  "subtitle"
]


# then process our path parents

# What if the path we're handed is the volume level?
if File.exist?(File.join(dirname, 'Metadata', 'DC.xml'))
  path = File.dirname(dirname)
else
  path = dirname
end

collection_array = []
while path != '.' do
  parent_key = File.dirname(path)
  parent_key = nil if parent_key == '.'
  collection_array << [
    path.sub(/\/$/,''),
    parent_key,
    File.basename(path).gsub("_"," ")
  ]
  path = File.dirname(path)
end
# We had to build the array from twig to trunk, but need to start the CSV from trunk to twig
collection_array.reverse.each { |collection_row| collection_csv << collection_row }

# What if the path we're handed is the volume level?
if File.exist?(File.join(dirname, 'Metadata', 'DC.xml'))
  ingest_volume_dir(dirname, volume_csv, page_csv)
else
  # loop through subdirectories recursively
  process_tree(dirname, collection_csv, volume_csv, page_csv)
end





# finally, close the csv files
collection_csv.close
volume_csv.close
page_csv.close
