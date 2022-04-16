require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone_number)
  phone_number.delete!('^0-9')
  phone_number.delete_prefix!('1') if phone_number.length == 11
  phone_number = nil unless phone_number.length == 10
  phone_number
end

def find_best_hours(hours)
  max_registration_hours = hours.values.max(3)
  ideal_hours = hours.select { |_, value| value > max_registration_hours[2] }
  ideal_hours.transform_keys! { |hour| "#{hour}:00" }
  puts ideal_hours.keys
end

def find_best_days(days)
  max_registration_days = days.values.max(3)
  ideal_days = days.select { |_, value| value > max_registration_days[2] }
  ideal_days.transform_keys! { |day| Date::DAYNAMES[day] }
  puts ideal_days.keys
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours = Hash.new(0)
days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  phone_numbers = clean_phone_numbers(row[:homephone])

  time = row[:regdate]
  t = Time.strptime(time, '%D %H')
  hour = t.hour
  weekday = t.wday
  hours[hour] += 1
  days[weekday] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

find_best_days(days)
find_best_hours(hours)
