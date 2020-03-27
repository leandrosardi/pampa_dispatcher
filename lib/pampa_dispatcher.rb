require 'pampa_workers'

module BlackStack
  
  class Dispatcher    
    attr_accessor :name
    # database information
    # :field_times, :field_start_time and :field_end_time maybe nil
    attr_accessor :table
    attr_accessor :field_primary_key
    attr_accessor :field_id
    attr_accessor :field_time 
    attr_accessor :field_times
    attr_accessor :field_start_time
    attr_accessor :field_end_time
    # max number of records assigned to a worker that have not started (:start_time field is nil)
    attr_accessor :queue_size 
    # max number of minutes that a job should take to process. if :end_time keep nil x minutes 
    # after :start_time, that's considered as the job has failed or interrumped
    attr_accessor :max_job_duration_minutes  
    # max number of times that a record can start to process & fail (:start_time field is not nil, 
    # but :end_time field is still nil after :max_job_duration_minutes)
    attr_accessor :max_try_times
    # additional function to returns an array of objects pending to be processed by a worker.
    # it should returns an array
    # keep it nil if you want to run the default function
    attr_accessor :occupied_function
    # additional function to decide if the worker can dispatch or not
    # example: use this function when you want to decide based on the remaining credits of the client
    # it should returns true or false
    # keep it nil if you want it returns always true
    attr_accessor :allowing_function
    # additional function to choose the records to launch
    # it should returns an array of IDs
    # keep this parameter nil if you want to use the default algorithm
    attr_accessor :selecting_function
    # additional function to choose the records to retry
    # keep this parameter nil if you want to use the default algorithm
    attr_accessor :relaunching_function
    # additional function to perform the update on a record to retry
    # keep this parameter nil if you want to use the default algorithm
    attr_accessor :relauncher_function
    # additional function to perform the update on a record to flag the starting of the job
    # by default this function will set the :field_start_time field with the current datetime, and it will increase the :field_times counter 
    # keep this parameter nil if you want to use the default algorithm
    attr_accessor :starter_function
    # additional function to perform the update on a record to flag the finishing of the job
    # by default this function will set the :field_end_time field with the current datetime 
    # keep this parameter nil if you want to use the default algorithm
    attr_accessor :finisher_function

    
    # setup dispatcher configuration here
    def initialize(h)
      self.name = h[:name]
      self.table = h[:table]
      self.field_primary_key = h[:field_primary_key]
      self.field_id = h[:field_id]
      self.field_time = h[:field_time]
      self.field_times = h[:field_times]
      self.field_start_time = h[:field_start_time]
      self.field_end_time = h[:field_end_time]
      self.queue_size = h[:queue_size]
      self.max_job_duration_minutes = h[:max_job_duration_minutes]  
      self.max_try_times = h[:max_try_times]
      self.occupied_function = h[:occupied_function]
      self.allowing_function = h[:allowing_function]
      self.selecting_function = h[:selecting_function]
      self.relaunching_function = h[:relaunching_function]
      self.relauncher_function = h[:relauncher_function]
    end
    
    # returns an array of objects pending to be processed by the worker.
    # it will select the records with :reservation_id == worker.id, and :start_time == nil
    def occupied_slots(worker)
      if self.occupied_function.nil?
        return self.table.where(self.field_id.to_sym => worker.id, self.field_start_time.to_sym => nil).all if !self.field_start_time.nil?
        return self.table.where(self.field_id.to_sym => worker.id).all if self.field_start_time.nil?
      else
        # TODO: validar que retorna un entero
        return self.occupied_function.call(worker, self)
      end
    end

    # returns the number of free slots in the procesing queue of this worker
    def available_slots(worker)
      occupied = self.occupied_slots(worker).size
      allowed = self.queue_size
      if occupied > allowed
        return 0
      else
        return allowed - occupied
      end
    end

    # decide if the worker can dispatch or not
    # example: use this function when you want to decide based on the remaining credits of the client
    # returns always true
    def allowing(worker)
      if self.allowing_function.nil?
        return true
      else
        # TODO: validar que retorna true o false
        return self.allowing_function.call(worker, self)
      end
    end

    # choose the records to dispatch
    # returns an array of IDs
    def selecting_dataset(worker, n)
      ds = self.table.select(self.field_primary_key.to_sym).where(self.field_id.to_sym => nil) 
      ds = ds.filter(self.field_end_time.to_sym => nil) if !self.field_end_time.nil?  
      ds = ds.filter("#{self.field_times.to_s} IS NULL OR #{self.field_times.to_s} < #{self.max_try_times.to_s}") if !self.field_times.nil? 
      ds.limit(n)
    end # selecting_dataset

    def selecting(worker, n)
      if self.selecting_function.nil?
        return self.selecting_dataset(worker, n).map { |o| o[self.field_primary_key.to_sym] }
      else
        # TODO: validar que retorna un array de strings
        return self.selecting_function.call(worker, self, n)
      end
    end

    # choose the records to retry
    # returns an array of IDs
    def relaunching_dataset(worker, n)
      ds = self.table.select(self.field_primary_key.to_sym).where("#{self.field_time.to_s} < '#{(Time.now - 60*self.max_job_duration_minutes.to_i).strftime('%Y-%m-%d %H:%M:%S').to_s}'")
      ds = ds.filter("#{self.field_end_time.to_s} IS NULL") if !self.field_end_time.nil?  
#      ds = ds.filter("( #{self.field_times.to_s} IS NULL OR #{self.field_times.to_s} < #{self.max_try_times.to_s} ) ") if !self.field_times.nil?
      ds = ds.limit(n)
    end

    def relaunching(worker, n)
      if self.relaunching_function.nil?
        return self.relaunching_dataset(worker, n).map { |o| o[self.field_primary_key.to_sym] }
      else
        # TODO: validar que retorna un array de strings
        return self.relaunching_function.call(worker, self, n)
      end
    end
    
    def relaunch(o)
      o[self.field_id.to_sym] = nil
      o[self.field_time.to_sym] = nil
      o[self.field_start_time.to_sym] = nil if !self.field_start_time.nil?
      o[self.field_end_time.to_sym] = nil if !self.field_end_time.nil?
      o.save      
    end

    def start(o)
      if self.starter_function.nil?
        o[self.field_start_time.to_sym] = now() if !self.field_start_time.nil?
        o[self.field_times.to_sym] = o[self.field_times.to_sym].to_i + 1
        o.save
      else
        self.starter_function.call(o, self)
      end
    end

    def finish(o)
      if self.finisher_function.nil?
        o[self.field_end_time.to_sym] = now() if !self.field_end_time.nil?
        o.save
      else
        self.finisher_function.call(o, self)
      end
    end
    
    # relaunch records
    def run_relaunch(worker)
      # relaunch failed records
      self.relaunching(worker, self.queue_size).each { |id|
        o = self.table.where(self.field_primary_key.to_sym => id).first
        if self.relauncher_function.nil?
          self.relaunch(o)
        else
          self.relauncher_function.call(o, self)
        end
        # release resources
        DB.disconnect
        GC.start
      }
    end # def run_relaunch
    
    # dispatch records
    # returns the # of records dispatched
    def run_dispatch(worker)
      # get # of available slots
      n = self.available_slots(worker)
      
      # dispatching n pending records
      i = 0
      if n>0
        self.selecting(worker, n).each { |id|
          # count the # of dispatched
          i += 1
          # dispatch records
          o = self.table.where(self.field_primary_key.to_sym => id).first
          o[self.field_id.to_sym] = worker.id
          o[self.field_time.to_sym] = now()
          o[self.field_start_time.to_sym] = nil if !self.field_start_time.nil?
          o[self.field_end_time.to_sym] = nil if !self.field_end_time.nil?
          o.save
          # release resources
          DB.disconnect
          GC.start        
        }
      end
      
      #      
      return i
    end
    
  end # class Dispatcher
  
end # module BlackStack