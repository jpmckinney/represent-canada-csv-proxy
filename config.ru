# coding: utf-8
require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'json'

require 'faraday'
require 'sinatra'
require 'active_support/core_ext/object/blank'
require 'active_support/inflector'

DIVISIONS = CSV.read(File.expand_path('../country-ca.csv', __FILE__), headers: true)

HEADER_MAP = {
  'full name' => :name,
  'district name' => :district_name,
  'primary role' => :elected_office,
  'source url' => :source_url,
  'first name' => :first_name,
  'last name' => :last_name,
  'party name' => :party_name,
  'email' => :email,
  'website' => :url,
  'photo url' => :photo_url,
  # personal_url
  'gender' => :gender,
}

OFFICE_HEADER_MAP = {
  'phone' => :tel,
  'fax' => :fax,
  'cell' => :cell,
}

ADDRESS_HEADERS = [
  'address line 1',
  'address line 2',
  'locality',
  'province',
  'postal code',
]

helpers do
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
get '/:id/:gid/:boundary_set' do
  source_url = "https://docs.google.com/spreadsheets/d/#{params[:id]}/export?gid=#{params[:gid]}&format=csv"
  response = Faraday.get(source_url)
  if response.status == 200
    map = {}

    if %w(census-subdivisions census-subdivisions-and-divisions).include?(params[:boundary_set])
      DIVISIONS.each do |division|
        unless division['classification'] == 'IRI'
          id = division['id'].rpartition(':')[2]
          if params[:sgc].nil? || id[0, 2] == params[:sgc]
            key = "#{division['id'].rpartition('/')[2].split(':')[0]}/#{division['name']}"
            map[key] ||= []
            map[key] << id
          end
        end
      end
    end

    data = []

    CSV.parse(response.body.force_encoding('utf-8'), headers: true, header_converters: lambda{|h| h.downcase}, converters: lambda{|c| c && c.strip}) do |row|
      district_id = row.delete('district id')
      if district_id && district_id[1].to_s[/\A\d{4}\z/]
        boundary_url = "/boundaries/census-divisions/#{district_id[1]}/"
      elsif district_id && district_id[1].to_s[/\A\d{7}\z/]
        boundary_url = "/boundaries/census-subdivisions/#{district_id[1]}/"
      else
        case params[:boundary_set]
        when 'census-subdivisions-and-divisions'
          key = "csd/#{row['district name']}"
          if map[key] && map[key].one?
            boundary_url = "/boundaries/census-subdivisions/#{map[key][0]}/"
          else
            key = "cd/#{row['district name']}"
            if map[key] && map[key].one?
              boundary_url = "/boundaries/census-divisions/#{map[key][0]}/"
            else
              halt(500, "no unique match for #{row['district name']} in census-subdivisions or census-divisions: #{map[key] && map[key].join(' ')}")
            end
          end
        when 'census-subdivisions'
          key = "csd/#{row['district name']}"
          if map[key] && map[key].one?
            boundary_url = "/boundaries/census-subdivisions/#{map[key][0]}/"
          else
            halt(500, "no unique match for #{row['district name']} in census-subdivisions: #{map[key] && map[key].join(' ')}")
          end
        else
          boundary_url = "/boundaries/#{params[:boundary_set]}/#{slugify(row['district name'])}/"
        end
      end

      record = {boundary_url: boundary_url}
      office = {}
      extra = {}

      HEADER_MAP.each do |header,field|
        if row[header].present?
          record[field] = row[header]
        end
      end

      OFFICE_HEADER_MAP.each do |header,field|
        if row[header].present?
          office[field] = row[header]
        end
      end

      (row.headers - HEADER_MAP.keys - OFFICE_HEADER_MAP.keys - ADDRESS_HEADERS).each do |header|
        if row[header].present?
          extra[header.gsub(' ', '_')] = row[header]
        end
      end

      if ADDRESS_HEADERS.any?{|header| row[header].present?}
        office[:address] = [
          row['address line 1'],
          row['address line 2'],
          "#{row['locality']} #{row['province']}  #{row['postal code'].to_s.upcase.sub(/\A([A-Z][0-9][A-Z])\s*([0-9][A-Z][0-9])\z/, '\1 \2')}".strip,
        ].select(&:present?).join("\n")
      end

      record[:gender] = record[:gender].to_s.upcase[0]

      [:tel, :fax, :cell].each do |field|
        digits = office[field].to_s.gsub(/\D/, '')
        if digits.size == 10
          digits = "1#{digits}"
        end
        if digits.size == 11 && digits[0] == '1'
          office[field] = digits.sub(/\A(\d)(\d{3})(\d{3})(\d{4})\z/, '\1 \2 \3-\4')
        end
      end

      record[:source_url] ||= source_url
      unless office.empty?
        record[:offices] = JSON.dump([office])
      end
      unless extra.empty?
        record[:extra] = JSON.dump(extra)
      end

      data << record
    end

    content_type 'application/json'
    JSON.dump(data)
  else
    response.status
  end
end

run Sinatra::Application
