# Pampa Dispatcher

**Pampa Dispatcher** distributes jobs along a pool of works over **[Pampa Workers](https://github.com/leandrosardi/pampa)**.

Note that any **dispatcher** works with a direct connection to the database. All the examples below will work this way.  

On the other hand, **workers** may be distributed worldwide, and don't require direct connection to the database.

Finally, if you are planning to use this gem to either scrape website at a large scale, or run a bot farm, you will should work with the [Stealth Browser Automation](https://github.com/leandrosardi/stealth_browser_automation) gem too. 
The examples in this document are using such gem to run a tiny web scraper.

# Installation

```cmd
gem install pampa_dispatcher
```

The **Pampa Dispatcher** gem requires **[Sequel](https://sequel.jeremyevans.net/)** 4.28.0.


# 1. Why Use Dispatchers?

A **dispatcher** manage one single connection to the database when selecting the jobs to process from such a database.
Getting each **worker** accessign the database to select a job to process would generates a high and expensive I/O workload. 

# 2. Getting Started

## 2.1. Setting Up a Data Model

Imagine you have to run a large farm of Pampa workers for a [distributed computing](https://en.wikipedia.org/wiki/Distributed_computing) task, or well you want to scrape some websites at a large scale.

The script below creates a table where you will place the URL of different web pages to scrape product prices.

```sql
create table webpage (
	[id] uniqueidentifier primary key not null,
	[url] varchar(8000) not null,
);
GO
```

You will insert some records of web pages that you want to scrape.

```sql
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/hp-stream-14-cb110ca-14-inch-laptop-white-intel-celeron-n4000-intel-uhd-600-4gb-ram-64gb-emmc-windows-10-s-4jc81uaabl/6000198793458');
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/hp-17-by0002ca-173-laptop-natural-silver-and-ash-silver-core-i5-8250u-intel-uhd-graphics-620-8gb-ddr4-1-tb-5400-rpm-sata-windows-10-home-4bq83uaabl/6000198528157');
insert into webpage (id, url) values (newid(), 'https://www.walmart.ca/en/ip/acer-aspire-3-156-laptop-amd-e2-9000-amd-radeon-r2-graphics-8-gb-ddr4-1-tb-hard-drive-windows-10-home-nxgnvaa019/6000197843008');
...
...
```

Since you are going to **distribute** the scraping job of all these URLs along too many **workers**, you need a way to know:

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

## 2.2. Setting Up the Dispatcher

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

Just below, setup a [Sequel](https://sequel.jeremyevans.net/) class to handle the database queries keeping them portable to any database engine.

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

## 2.3. Running Workers

*(pending)*

## 2.4. Running Dispatcher

*(pending)*

# 3. Error Handling, Job-Retry and Fault Tolerance

*(pending)*



