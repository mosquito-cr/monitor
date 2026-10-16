module Mosquito::InspectWeb::Failures
  record Failure,
    job_run : Mosquito::Api::JobRun,
    queue : String,
    state : String,
    failed_at : Time

  def self.recent(limit : Int32 = 100) : Array(Failure)
    failures = [] of Failure

    Mosquito::Api::Queue.all.each do |queue|
      {
        "dead"     => queue.dead_job_runs,
        "retrying" => queue.scheduled_job_runs,
      }.each do |state, job_runs|
        job_runs.each do |job_run|
          next unless job_run.found?
          next unless failed_at = job_run.failed_at
          failures << Failure.new(job_run, queue.name, state, failed_at)
        end
      end
    end

    failures.sort_by!(&.failed_at).reverse!.first(limit)
  end
end

get "/failures" do |env|
  Current.tab = :failures
  failures = Mosquito::InspectWeb::Failures.recent
  Mosquito::InspectWeb.render "failures.html.ecr"
end
