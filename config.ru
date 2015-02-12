# coding: utf-8
require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'json'

require 'faraday'
require 'sinatra'

DIVISIONS = CSV.read(File.expand_path('../country-ca.csv', __FILE__), headers: true)

helpers do
  def find_division_by_id(id)
    DIVISIONS.find do |division|
      division['id'] == id
    end
  end

  def find_division_by_name_and_type(name, type)
    DIVISIONS.find do |division|
      division['name'] == name && division['id'].rpartition('/')[2].split(':')[0] == type
    end
  end

  # @see https://docs.djangoproject.com/en/1.7/ref/utils/#django.utils.text.slugify
  # @see https://gist.github.com/jpmckinney/1374639
  def slugify(value)
    value.tr(
      "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
      "aaaaaaaaaaaaaaaaaaccccccccccddddddeeeeeeeeeeeeeeeeeegggggggghhhhiiiiiiiiiiiiiiiiiijjkkkllllllllllnnnnnnnnnnnoooooooooooooooooorrrrrrsssssssssttttttuuuuuuuuuuuuuuuuuuuuwwyyyyyyzzzzzz"
    ).gsub(/[^\w\s—–-]/, '').strip.downcase.gsub(/[\s—–-]+/, '-') # m-dash, n-dash
  end
end

# Must set "Anyone who has the link can view" and "Publish to the web"
get '/:id' do
  response = Faraday.get("https://docs.google.com/spreadsheets/d/#{params[:id]}/export?gid=0&format=csv")
  if response.status == 200
    data = []

    CSV.parse(response.body.force_encoding('utf-8'), headers: true, header_converters: lambda{|h| h.downcase}) do |row|
      division = find_division_by_name_and_type(row['district name'], 'csd')
      if division
        boundary_url = "/boundaries/census-subdivisions/#{division['id'].rpartition(':')[2]}/"
      else
        division = find_division_by_name_and_type(row['district name'], 'borough')
        if division
          parent = find_division_by_id(division['id'].rpartition('/')[0])
          boundary_url = "/boundaries/#{slugify(parent['name'])}-boroughs/#{slugify(division['name'])}/"
        end
      end

      if division
        data << {
          boundary_url: boundary_url,
          first_name: row['first name'],
          last_name: row['last name'],
          party_name: row['party name'],
          email: row['email'],
        }
      else
        halt(500, "no match for #{row['district name']}")
      end
    end

    content_type 'application/json'
    JSON.dump(data)
  else
    response.status
  end
end

run Sinatra::Application
