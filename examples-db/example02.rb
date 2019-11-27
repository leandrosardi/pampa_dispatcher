=begin
t = Time.now
puts "t:#{t.to_s}:."
puts "t:#{t.strftime('%Y-%m-%d %H:%M:%S')}:."

u = t - 60*60*24*20 # menos 20 dias
puts "u:#{u.to_s}:."
puts "u:#{u.strftime('%Y-%m-%d %H:%M:%S')}:."
#(self.max_job_duration_minutes.to_f / 1440.to_f).strftime('%Y-%m-%d %H:%M:%S')

exit(0)
=end

require 'pampa_workers'
require_relative '../lib/pampa_dispatcher'

# setup database connection parameters
BlackStack::Pampa::set_db_params({
  :db_url => 'Leandro1\\DEV',
  :db_port => 1433,
  :db_name => 'kepler',
  :db_user => '',
  :db_password => '',  
})

# tell Pampa that you want to connect directly to the database, instead to ask the BlackStack division directory
BlackStack::Pampa::set_division_name(
  'local'
)

# perform database connection
DB = BlackStack::Pampa::db_connection

# Create a DB class using Sequel
class WebPage < Sequel::Model(:webpage)
  # TODO: add some methods that you consider here
end

# setup dispatcher for scraping webpages
d = BlackStack::Dispatcher.new({
  :name => 'dispatcher.scrape',
  # database information
  :table => WebPage,
  :field_primary_key => 'id',
  :field_id => 'scrape_reservation_id',
  :field_time => 'scrape_reservation_time', 
  :field_times => 'scrape_reservation_times',
  :field_start_time => 'scrape_start_time',
  :field_end_time => 'scrape_end_time',
  # max number of records assigned to a worker that have not started (:start_time field is nil)
  :queue_size => 5, 
  # max number of minutes that a job should take to process. if :end_time keep nil x minutes 
  # after :start_time, that's considered as the job has failed or interrumped
  :max_job_duration_minutes => 15,  
  # max number of times that a record can start to process & fail (:start_time field is not nil, 
  # but :end_time field is still nil after :max_job_duration_minutes)
  :max_try_times => 5,
  # additional function to decide how many records are pending for processing
  # it should returns an integer
  # keep it nil if you want to run the default function
  :occupied_function => nil,
  # additional function to decide if the worker can dispatch or not
  # example: use this function when you want to decide based on the remaining credits of the client
  # it should returns true or false
  # keep it nil if you want it returns always true
  :allowing_function => nil,
  # additional function to choose the records to launch
  # it should returns an array of IDs
  # keep this parameter nil if you want to use the default algorithm
  :selecting_function => nil,
  # additional function to choose the records to retry
  # keep this parameter nil if you want to use the default algorithm
  :relaunching_function => nil,
})

# load pampa sequel classes
BlackStack::Pampa::require_db_classes

# load a worker
print 'Load a worker... '
w = BlackStack::Worker.first
puts "done (#{w.name})"

# checking how many occupied slots does this worker have
print 'Ask for occupied slots... '
n = d.occupied_slots(w).size
puts "done (#{n.to_s})"

# 
print 'Ask for available slots... '
m = d.available_slots(w)
puts "done (#{m.to_s})"

# 
print 'Ask if worker is allowed to dispatch... '
b = d.allowing(w)
puts "done (#{b.to_s})"

#print "\r\nQuery of available records to dispatch... "
#sql = d.selecting_dataset(w, 5).sql
#puts "done ( #{sql.to_s} )\r\n\r\n"

#print "\r\nQuery of available records to relaunch... "
#sql = d.relaunching_dataset(w, 5).sql
#puts "done ( #{sql.to_s} )\r\n\r\n"

puts ""

print 'Force all records ready to dispatch... '
DB.execute(
  "update webpage set " + 
  " scrape_reservation_id=null, " + 
  " scrape_reservation_time = null, " + 
  " scrape_reservation_times = null, " +
  " scrape_start_time = null, " +
  " scrape_end_time = null "
)
puts 'done'

# 
print 'Ask for available records to dispatch... '
a = d.selecting(w, 5)
puts "done (#{a.size.to_s} records)"

# 
print 'Ask for occupied slots... '
b = d.relaunching(w, 5)
puts "done (#{b.size.to_s} records)"

puts ""

print 'Force all as failed but allowed to relaunch... '
DB.execute(
  "update webpage set " + 
  " scrape_reservation_id='#{w.id.to_guid}', " + 
  " scrape_reservation_time = dateadd(mi, -60, getdate()), " + 
  " scrape_reservation_times = 4, " +
  " scrape_start_time = null, " +
  " scrape_end_time = null "
)
puts 'done'

# 
print 'Ask for available records to dispatch... '
a = d.selecting(w, 5)
puts "done (#{a.size.to_s} records)"

# 
print 'Ask for occupied slots... '
b = d.relaunching(w, 5)
puts "done (#{b.size.to_s} records)"

puts ""

print 'Force all as failed and NOT allowed to relaunch yet (just reserved 2 minutes ago)... '
DB.execute(
  "update webpage set " + 
  " scrape_reservation_id='#{w.id.to_guid}', " + 
  " scrape_reservation_time = dateadd(mi, -2, getdate()), " + 
  " scrape_reservation_times = 4, " +
  " scrape_start_time = null, " +
  " scrape_end_time = null "
)
puts 'done'

# 
print 'Ask for available records to dispatch... '
a = d.selecting(w, 5)
puts "done (#{a.size.to_s} records)"

# 
print 'Ask for occupied slots... '
b = d.relaunching(w, 5)
puts "done (#{b.size.to_s} records)"

puts ""

print 'Force all as failed and NOT allowed to relaunch (too many tries)... '
DB.execute(
  "update webpage set " + 
  " scrape_reservation_id='#{w.id.to_guid}', " + 
  " scrape_reservation_time = dateadd(mi, -60, getdate()), " + 
  " scrape_reservation_times = 5, " +
  " scrape_start_time = null, " +
  " scrape_end_time = null "
)
puts 'done'

# 
print 'Ask for available records to dispatch... '
a = d.selecting(w, 5)
puts "done (#{a.size.to_s} records)"

# 
print 'Ask for occupied slots... '
b = d.relaunching(w, 5)
puts "done (#{b.size.to_s} records)"
