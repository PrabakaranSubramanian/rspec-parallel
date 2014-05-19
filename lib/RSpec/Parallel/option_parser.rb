module RSpec
  module Parallel
    class Parser < RSpec::Core::Parser
      def parser(options)
      OptionParser.new do |parser|
        parser.banner = "Usage: rspec [options] [files or directories]\n\n"

        parser.on('-I PATH', 'Specify PATH to add to $LOAD_PATH (may be used more than once).') do |dir|
          options[:libs] ||= []
          options[:libs] << dir
        end

        parser.on('-r', '--require PATH', 'Require a file.') do |path|
          options[:requires] ||= []
          options[:requires] << path
        end

        parser.on('-O', '--options PATH', 'Specify the path to a custom options file.') do |path|
          options[:custom_options_file] = path
        end

        parser.on('--order TYPE[:SEED]', 'Run examples by the specified order type.',
                  '  [defined] examples and groups are run in the order they are defined',
                  '  [rand]    randomize the order of groups and examples',
                  '  [random]  alias for rand',
                  '  [random:SEED] e.g. --order random:123') do |o|
          options[:order] = o
        end

        parser.on('--seed SEED', Integer, 'Equivalent of --order rand:SEED.') do |seed|
          options[:order] = "rand:#{seed}"
        end

        parser.on('--fail-fast', 'Abort the run on first failure.') do |o|
          options[:fail_fast] = true
        end

        parser.on('--no-fail-fast', 'Do not abort the run on first failure.') do |o|
          options[:fail_fast] = false
        end

        parser.on('--failure-exit-code CODE', Integer, 'Override the exit code used when there are failing specs.') do |code|
          options[:failure_exit_code] = code
        end

        parser.on('--dry-run', 'Print the formatter output of your suite without',
                  '  running any examples or hooks') do |o|
          options[:dry_run] = true
        end

        parser.on('-X', '--[no-]drb', 'Run examples via DRb.') do |o|
          options[:drb] = o
        end

        parser.on('--drb-port PORT', 'Port to connect to the DRb server.') do |o|
          options[:drb_port] = o.to_i
        end

        parser.on('--init', 'Initialize your project with RSpec.') do |cmd|
          RSpec::Support.require_rspec_core "project_initializer"
          ProjectInitializer.new.run
          exit
        end

        parser.separator("\n  **** Output ****\n\n")

        parser.on('-f', '--format FORMATTER', 'Choose a formatter.',
                '  [p]rogress (default - dots)',
                '  [d]ocumentation (group and example names)',
                '  [h]tml',
                '  [j]son',
                '  custom formatter class name') do |o|
          options[:formatters] ||= []
          options[:formatters] << [o]
        end

        parser.on('-o', '--out FILE',
                  'Write output to a file instead of $stdout. This option applies',
                  '  to the previously specified --format, or the default format',
                  '  if no format is specified.'
                 ) do |o|
          options[:formatters] ||= [['progress']]
          options[:formatters].last << o
        end

        parser.on('--deprecation-out FILE', 'Write deprecation warnings to a file instead of $stderr.') do |file|
          options[:deprecation_stream] = file
        end

        parser.on('-b', '--backtrace', 'Enable full backtrace.') do |o|
          options[:full_backtrace] = true
        end

        parser.on('-c', '--[no-]color', '--[no-]colour', 'Enable color in the output.') do |o|
          options[:color] = o
        end

        parser.on('-p', '--[no-]profile [COUNT]', 'Enable profiling of examples and list the slowest examples (default: 10).') do |argument|
          options[:profile_examples] = if argument.nil?
                                         true
                                       elsif argument == false
                                         false
                                       else
                                         begin
                                           Integer(argument)
                                         rescue ArgumentError
                                           RSpec.warning "Non integer specified as profile count, seperate " +
                                                       "your path from options with -- e.g. " +
                                                       "`rspec --profile -- #{argument}`",
                                                       :call_site => nil
                                           true
                                         end
                                       end
        end

        parser.on('-w', '--warnings', 'Enable ruby warnings') do
          $VERBOSE = true
        end

        parser.on('--parallel-test NUMBER', 'Run the tests with the specified number of parallel threads (default: 1).') do |n|
          options[:thread_maximum] = if !n.nil?
                                      begin
                                        Integer(n)
                                      rescue ArgumentError
                                        RSpec.warning "Non integer specified as number of parallel threads, seperate " +
                                                       "your path from options with a space e.g. " +
                                                       "`rspec --parallel-test #{n}`",
                                                       :call_site => nil
                                        1
                                      end
                                    end
        end

        parser.separator <<-FILTERING

  **** Filtering/tags ****

    In addition to the following options for selecting specific files, groups,
    or examples, you can select a single example by appending the line number to
    the filename:

      rspec path/to/a_spec.rb:37

FILTERING

        parser.on('-P', '--pattern PATTERN', 'Load files matching pattern (default: "spec/**/*_spec.rb").') do |o|
          options[:pattern] = o
        end

        parser.on('-e', '--example STRING', "Run examples whose full nested names include STRING (may be",
                                            "  used more than once)") do |o|
          (options[:full_description] ||= []) << Regexp.compile(Regexp.escape(o))
        end

        parser.on('-t', '--tag TAG[:VALUE]',
                  'Run examples with the specified tag, or exclude examples',
                  'by adding ~ before the tag.',
                  '  - e.g. ~slow',
                  '  - TAG is always converted to a symbol') do |tag|
          filter_type = tag =~ /^~/ ? :exclusion_filter : :inclusion_filter

          name,value = tag.gsub(/^(~@|~|@)/, '').split(':',2)
          name = name.to_sym

          options[filter_type] ||= {}
          options[filter_type][name] = case value
                                         when  nil        then true # The default value for tags is true
                                         when 'true'      then true
                                         when 'false'     then false
                                         when 'nil'       then nil
                                         when /^:/        then value[1..-1].to_sym
                                         when /^\d+$/     then Integer(value)
                                         when /^\d+.\d+$/ then Float(value)
                                       else
                                         value
                                       end
        end

        parser.on('--default-path PATH', 'Set the default path where RSpec looks for examples (can',
                                         '  be a path to a file or a directory).') do |path|
          options[:default_path] = path
        end

        parser.separator("\n  **** Utility ****\n\n")

        parser.on('-v', '--version', 'Display the version.') do
          puts RSpec::Core::Version::STRING
          exit
        end

        # these options would otherwise be confusing to users, so we forcibly prevent them from executing
        # --I is too similar to -I
        # -d was a shorthand for --debugger, which is removed, but now would trigger --default-path
        invalid_options = %w[-d --I]

        parser.on_tail('-h', '--help', "You're looking at it.") do
          # removing the blank invalid options from the output
          puts parser.to_s.gsub(/^\s+(#{invalid_options.join('|')})\s*$\n/,'')
          exit
        end

        # this prevents usage of the invalid_options
        invalid_options.each do |option|
          parser.on(option) do
            raise OptionParser::InvalidOption.new
          end
        end

      end
    end
    end
  end
end