module RSpec
  module Parallel
    # ExampleGroupThreadRunner is a class used to execute [ExampleGroup] 
    # classes in parallel as part of rspec-core.  When running in parallel 
    # the order of example groups will not be honoured.  
    # This class is used to ensure that we have a way of keeping track of
    # the number of threads being created and preventing utilization of
    # more than the specified number
    # Additionally, this class will contain a mutex used to prevent access
    # to shared variables within sub-threads
    class ExampleGroupThreadRunner
      attr_accessor :thread_array, :max_threads, :mutex, :used_threads

      # Creates a new instance of ExampleGroupThreadRunner.
      # @param max_threads [Integer] the maximum limit of threads that can be used
      # @param mutex [Mutex] a semaphore used to prevent access to shared variables in
      # sub-threads such as those used by [ExampleThreadRunner]
      # @param used_threads [Integer] the current number of threads being used
      def initialize(max_threads = 1, mutex = Mutex.new, used_threads = 0)
        @max_threads = max_threads
        @mutex = mutex
        @used_threads = used_threads
        @thread_array = []
      end

      # Method will run an [ExampleGroup] inside a [Thread] to prevent blocking
      # execution.  The new [Thread] is added to an array for tracking and
      # will automatically remove itself when done
      # @param example_group [ExampleGroup] the group to be run inside a [Thread]
      # @param reporter [Reporter] the passed in reporting class used for 
      # tracking
      def run(example_group, reporter)
        @thread_array.push Thread.start {
          puts "example_group.run_parallel"
          example_group.run_parallel(reporter, @max_threads, @mutex, @used_threads)
          @thread_array.delete Thread.current
        }
      end

      # Method will wait for all threads to complete.  On completion threads
      # remove themselves from the @thread_array so an empty array means they
      # completed
      def wait_for_completion
        @thread_array.each do |t|
          t.join
        end
      end
    end
  end
end
