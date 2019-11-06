class TopicDueDate < DueDate
  belongs_to :topic, class_name: "SignUpTopic", foreign_key: "parent_id"
  belongs_to :deadline_type, class_name: "DeadlineType", foreign_key: "deadline_type_id"

  # adds a new deadline if not present,
  # updates the date if already present
  def self.upsert_drop_deadline_job(assignment_id, topic, drop_topic_input)
    # can create constants for all deadline types and use those when required
    deadline_type_id = DeadlineHelper::DEADLINE_TYPE_DROP_TOPIC
    drop_topic_date = TopicDueDate.where(parent_id: topic.id, deadline_type_id: deadline_type_id).first rescue nil

    calc_drop_topic_date = get_drop_topic_deadline_date(assignment_id, topic.id, drop_topic_input)

    # if drop topic deadline is not in db, make an entry
    if drop_topic_date.nil?
      # if user sets a date before creating the first entry
      due_at = (drop_topic_input.nil? || drop_topic_input.blank?) ? nil : calc_drop_topic_date

      # add delayed job to drop waitlisted teams after deadline passes
      delayed_job_id = modify_delayed_job(topic.id, calc_drop_topic_date, nil, false)

      TopicDueDate.create(due_at: due_at,
                          parent_id: topic.id,
                          deadline_type_id: deadline_type_id,
                          type: DeadlineHelper::TOPIC_DEADLINE_TYPE,
                          delayed_job_id: delayed_job_id)
    else
      update_delayed_job = true

      if !drop_topic_date.due_at.nil? && (drop_topic_input.nil? || drop_topic_input.blank?)
        # if drop topic deadline is deleted
        due_at = nil
      elsif drop_topic_date.due_at.nil? && !(drop_topic_input.nil? || drop_topic_input.blank?)
        # if drop topic deadline is entered first time
        due_at = calc_drop_topic_date
      elsif !drop_topic_date.due_at.nil? && drop_topic_date.due_at.to_datetime.strftime(DeadlineHelper::DATE_FORMATTER_DROP_DEADLINE) != calc_drop_topic_date.strftime(DeadlineHelper::DATE_FORMATTER_DROP_DEADLINE)
        # if drop topic deadline is updated
        due_at = calc_drop_topic_date
      else
        # if updated date is same as existing, don't update the delayed job
        update_delayed_job = false
      end

      if update_delayed_job
        delayed_job_id = modify_delayed_job(topic.id, calc_drop_topic_date, drop_topic_date.delayed_job_id, true)
        drop_topic_date.update_attributes(due_at: due_at, delayed_job_id: delayed_job_id)
      end
    end
  end

  # check the user input date and return the accurate deadline for dropping topics
  private
  def self.get_drop_topic_deadline_date(assignment_id, topic_id, drop_topic_input)
    expected_drop_deadline_date = DueDate.get_deadline_to_drop_topic(assignment_id, topic_id)

    if drop_topic_input.nil? || drop_topic_input.blank?
      return expected_drop_deadline_date
    end

    drop_topic_date = DateTime.parse(drop_topic_input)

    # if user sets drop topic deadline ahead of submission date, use submission date
    return (drop_topic_date.utc > expected_drop_deadline_date.utc) ? expected_drop_deadline_date : drop_topic_date
  end

  # this method either adds a new job to the queue or deletes
  # an existing job and replaces it with a new one
  private
  def self.modify_delayed_job(topic_id, drop_topic_date, delayed_job_id, job_present)
    if job_present
      remove_job_from_queue(delayed_job_id)
    end

    mins_left = calculate_mins_left(drop_topic_date)
    return add_job_to_queue(mins_left, topic_id, "drop_topic", drop_topic_date)
  end

  private
  def self.calculate_mins_left(drop_topic_date)
    curr_time = DateTime.now
    ((curr_time - drop_topic_date) * 24 * 60).to_i
  end

  private
  def self.add_job_to_queue(min_left, topic_id, deadline_type, due_at)
    delayed_job_id = MailWorker.perform_in(min_left * 60, topic_id, deadline_type, due_at)
    return delayed_job_id
  end

  private
  def self.remove_job_from_queue(job_id)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      current_job_id = job.args.first
      job.delete if job_id == current_job_id
    end
  end
end
