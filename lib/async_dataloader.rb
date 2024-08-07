require "async/variable"

# A GraphQL::Dataloader implementation that uses the async gem all the way
# to be compatible with running on falcon.
# Uses private API, so be careful when upgrading graphql-ruby
class AsyncDataloader
  def self.use(schema)
    schema.dataloader_class = self
  end

  def self.with_dataloading(&block)
    dataloader = new
    dataloader.run_for_result(&block)
  end

  def initialize
    @source_cache = Hash.new { |h, k| h[k] = {} }
    @pending_jobs = []
  end

  def get_fiber_variables = {} # rubocop:disable Naming/AccessorMethodName
  def set_fiber_variables(vars); end # rubocop:disable Naming/AccessorMethodName
  def cleanup_fiber; end

  def with(source_class, *batch_args, **batch_kwargs)
    batch_key = source_class.batch_key_for(*batch_args, **batch_kwargs)
    @source_cache[source_class][batch_key] ||= begin
      source = source_class.new(*batch_args, **batch_kwargs)
      source.setup(self)
      source
    end
  end

  def yield = run_next_pending_jobs_or_sources
  def append_job(&block) = @pending_jobs << block
  def clear_cache = @source_cache.each_value { |batch| batch.each_value(&:clear_cache) }

  # Use a self-contained queue for the work in the block.
  def run_isolated(&block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    prev_queue = @pending_jobs
    prev_pending_keys = {}
    @source_cache.each_value do |batched_sources|
      batched_sources.each_value do |source|
        if source.pending?
          prev_pending_keys[source] = source.pending.dup
          source.pending.clear
        end
      end
    end

    @pending_jobs = []
    run_for_result(&block)
  ensure
    @pending_jobs = prev_queue
    prev_pending_keys.each do |source, pending|
      pending.each do |key, value|
        source.pending[key] = value unless source.results.key?(key)
      end
    end
  end

  def run
    fiber_vars = get_fiber_variables
    Sync do |runner_task|
      runner_task.annotate "Dataloader runner"
      set_fiber_variables(fiber_vars)
      run_next_pending_jobs_or_sources while any_pending_jobs? || any_pending_sources?
      cleanup_fiber
    end
  end

  def run_for_result(&block)
    result = Async::Variable.new
    append_job { result.resolve(block.arity == 1 ? yield(self) : yield) }
    run
    result.value
  end

  private

  def run_next_pending_jobs_or_sources
    task = if any_pending_jobs?
             run_pending_jobs
           elsif any_pending_sources?
             run_pending_sources
           end
    task.wait
  end

  def run_pending_jobs
    fiber_vars = get_fiber_variables
    Async do |job_task|
      job_task.annotate "Dataloader job runner"
      set_fiber_variables(fiber_vars)
      while (job = pending_jobs.shift)
        job.call
      end
      cleanup_fiber
    end
  end

  def run_pending_sources
    fiber_vars = get_fiber_variables
    Async do |source_task|
      source_task.annotate "Dataloader source runner"
      set_fiber_variables(fiber_vars)
      pending_sources.each(&:run_pending_keys)
      cleanup_fiber
    end
  end

  def pending_jobs = @pending_jobs
  def any_pending_jobs? = @pending_jobs.any?
  def pending_sources = @source_cache.each_value.flat_map(&:values).select(&:pending)
  def any_pending_sources? = @source_cache.each_value.any? { |batch| batch.each_value.any?(&:pending?) }
end
