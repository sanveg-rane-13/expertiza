# This helper contains methods to manipulate due dates of topics in an assignment. This helper if used by
# sign_up_controller
module DeadlineHelper
  DEADLINE_TYPE_SUBMISSION = 1
  DEADLINE_TYPE_REVIEW = 2
  DEADLINE_TYPE_METAREVIEW = 5
  DEADLINE_TYPE_DROP_TOPIC = 6
  DEADLINE_TYPE_SIGN_UP = 7
  DEADLINE_TYPE_TEAM_FORMATION = 8

  TOPIC_DEADLINE_TYPE = 'TopicDueDate'
  ASSNT_DEADLINE_TYPE = 'AssignmentDueDate'

  # Creates a new topic deadline for topic specified by topic_id.
  # The deadline itself is specified by due_date object which contains several values which specify
  # type { submission deadline, metareview deadline, etc.} a set of other parameters that
  # specify whether submission, review, metareview, etc. are allowed for the particular deadline
  def create_topic_deadline(due_date, offset, topic_id)
    topic_deadline = TopicDueDate.new
    topic_deadline.parent_id = topic_id
    topic_deadline.due_at = Time.zone.parse(due_date.due_at.to_s) + offset.to_i
    topic_deadline.deadline_type_id = due_date.deadline_type_id
    # select count(*) from topic_deadlines where late_policy_id IS NULL;
    # all 'late_policy_id' in 'topic_deadlines' table is NULL
    # topic_deadline.late_policy_id = nil
    topic_deadline.submission_allowed_id = due_date.submission_allowed_id
    topic_deadline.review_allowed_id = due_date.review_allowed_id
    topic_deadline.review_of_review_allowed_id = due_date.review_of_review_allowed_id
    topic_deadline.round = due_date.round
    topic_deadline.save
  end

  # This method either adds a new job to the queue or deletes
  # an existing job and replaces it with a new one
  def modify_delayed_job(topic, delayed_job_id, job_present)
    if job_present == false
      min_left = topic.due_at - Time.now
      delayed_job_id = add_job_to_queue(min_left, topic.id, "drop_topic", topic.due_at)
      delayed_job_id
    else
      remove_job_from_queue(delayed_job_id)
      min_left = topic.due_at - Time.now
      delayed_job_id = add_job_to_queue(min_left, topic.id, "drop_topic", topic.due_at)
      delayed_job_id
    end
  end

  def add_job_to_queue(min_left, topic_id, deadline_type, due_at)
    delayed_job_id = MailWorker.perform_in(min_left * 60, topic_id, deadline_type, due_at)
    return delayed_job_id
  end

  def remove_job_from_queue(job_id)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      current_job_id = job.args.first
      job.delete if job_id == current_job_id
    end
  end

end
