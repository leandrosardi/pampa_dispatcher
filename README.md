# Pampa Dispatcher

This gem is part of the BlackStack framework.

It works over [Pampa](https://github.com/leandrosardi/pampa), and is useful to distribute work along a pool of Pampa workers.

Note that any dispatcher works with a direct connection to the database. All the examples below will work this way.  

Finally, if you are planning to use this gem to either scrape website at a large scale, or run a bot farm, you will should work with the [Stealth Browser Automation](https://github.com/leandrosardi/stealth_browser_automation) gem too. 
The examples in this document are using such gem to run a tiny web scraper.

## Creating a Database Schema

Imagine you have to run a large farm of Pampa workers for a [distributed computing](https://en.wikipedia.org/wiki/Distributed_computing) task, or well you want to scrape some websites at a large scale.

The script below creates a table where you will place the URL of different web pages to scrape product prices.

```sql
create table webpage (
	[id] uniqueidentifier primary key not null,
	[url] varchar(8000) not null,
);
GO
```

Insert some records of webpages that you want to scrape.
In order to make your example more effective, insert as many records as you can.
One thausand records is good. 
```sql
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/hp-stream-14-cb110ca-14-inch-laptop-white-intel-celeron-n4000-intel-uhd-600-4gb-ram-64gb-emmc-windows-10-s-4jc81uaabl/6000198793458');
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/hp-17-by0002ca-173-laptop-natural-silver-and-ash-silver-core-i5-8250u-intel-uhd-graphics-620-8gb-ddr4-1-tb-5400-rpm-sata-windows-10-home-4bq83uaabl/6000198528157');
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/acer-aspire-3-156-laptop-amd-e2-9000-amd-radeon-r2-graphics-8-gb-ddr4-1-tb-hard-drive-windows-10-home-nxgnvaa019/6000197843008');
...
```

Since you are going to distribute the scraping of all these URLs along too many distributed Pampa workers, you need a way to know:

* which record has been assigned to what worker;
* when it has been assigned;
* which record has started;
* which record has finished successfully;
* which record has failed, and how many times did it failed.

So you have to add the column below to the *webpage* table

```sql
alter table webpage add scrape_reservation_id uniqueidentifier null;
GO

alter table webpage add scrape_reservation_time datetime null;
GO

alter table webpage add scrape_reservation_times int null;
GO

alter table webpage add scrape_start_time datetime null;
GO

alter table webpage add scrape_end_time datetime null;
GO
```

## Setting Up the Dispatcher

First step in your script is to connect the database.

```ruby
require 'pampa'
require 'pampa_dispatcher'

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
```

Just below, setup a Sequel class to handle the database queries keeping them portable to any database engine.

```ruby
# Create a DB class using Sequel
class WebPage < Sequel::Model(:webpage)
  # TODO: add some methods that you consider here
end
```
 
Finally, setup the dispatcher,

```ruby
# setup dispatcher for scraping webpages
dispatcher = BlackStack::Dispatcher.new({
  :name => 'dispatcher.scrape',
  # database information
  :table => WebPage, # Note, that we are sending a class object here
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
  :queue_slots_function => nil,
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
```

## Getting Dispatcher Status
*(pending: example02.rb)*

## Dispatching
*(pending: running dispatcher.run)*

## Queries Optimization
*(pending: get the default SQL scripts)*



