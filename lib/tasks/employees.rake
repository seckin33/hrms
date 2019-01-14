namespace :employees do
  desc 'Sends advance notification about new employees first day'
  task start_date: :environment do
    ids = []
    employees = Person.not_deleted.where(status: Person::CURRENT_EMPLOYEE_STATUSES)

    # who comes 1st day in 1 week
    ids += employees
      .where('start_date >= ? AND start_date < ?', 7.days.since.strftime('%F'), 8.days.since.strftime('%F'))
      .pluck(:id)

    # who was created yesterday and comes 1st day in 1 week
    ids += employees
      .where('created_at >= ? AND start_date < ?', 1.day.ago.strftime('%F'), 8.days.since.strftime('%F'))
      .where('start_date >= ? AND start_date < ?', Time.zone.now.strftime('%F'), 8.days.since.strftime('%F'))
      .pluck(:id)

    # if today is friday and comes 1st day on monday
    if Time.zone.now.strftime('%w') == '5'
      ids += employees
        .where('start_date >= ? AND start_date < ?', 3.days.since.strftime('%F'), 4.days.since.strftime('%F'))
        .pluck(:id)
    else
      # comes 1st day tomorrow
      ids += employees
        .where('start_date >= ? AND start_date < ?', 1.days.since.strftime('%F'), 2.days.since.strftime('%F'))
        .pluck(:id)
    end

    User.where(notifications_enabled: true).pluck(:id).each do |user_id|
      ids.uniq.each do |person_id|
        EmployeesMailer.start_date(user_id, person_id).deliver_now
      end
    end
  end

  desc 'Sends advance notification about 1-1 meetings'
  task one_on_one_meeting: :environment do
    employees = Person.not_deleted.current_employee
      .where('city ILIKE ?', ENV['MAIN_CITY'])
      .where('start_date < ?', 3.months.ago.strftime('%F'))
      .where('last_one_on_one_meeting_at IS NULL OR last_one_on_one_meeting_at < ?', 3.months.ago.strftime('%F'))
      .reorder('last_one_on_one_meeting_at IS NOT NULL, last_one_on_one_meeting_at ASC')
      .order(:name)

    User.where(employee_notifications_enabled: true).pluck(:id).each do |user_id|
      EmployeesMailer.one_on_one(user_id, employees).deliver_now
    end
  end

  desc 'Sends advance notification about performance reviews'
  task performance_review: :environment do
    service = PerformanceReviewStatsCollector.new(
      start_date: 10.years.ago.strftime('%d-%m-%Y'),
      finish_date: 1.month.since.strftime('%d-%m-%Y'),
      order: 'next_review'
    )
    service.perform
    employees = service.scope

    User.where(employee_notifications_enabled: true).pluck(:id).each do |user_id|
      EmployeesMailer.performance_review(user_id, employees).deliver_now
    end
  end

  desc 'Sends notification when employee worked for 1 month already'
  task one_month: :environment do
    works_n_months(1)
  end

  desc 'Sends notification when employee worked for 3 month already'
  task three_months: :environment do
    works_n_months(3)
  end

  private def works_n_months(months)
    employees = Person.not_deleted.current_employee
                  .where('start_date <= ?', months.months.ago.strftime('%F'))
                  .where('start_date > ?', (months.months.ago - 1.day).strftime('%F'))
                  .where('finish_date IS NULL')
    return if employees.size == 0
    User.where(employee_notifications_enabled: true).pluck(:id).each do |user_id|
      EmployeesMailer.n_months(user_id, employees, months).deliver_now
    end
  end
end
