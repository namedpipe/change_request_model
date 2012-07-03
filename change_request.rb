
class ChangeRequest < ActiveRecord::Base
	VALID_CURRENT_OWNERS = ["admin","submitter"]
	VALID_STATUSES = ["NEW","ACCEPTED","NEEDS MORE INFO","COMPLETE","NO ACTION"]
	CLOSED_STATUSES = ["COMPLETE","NO ACTION"]
	VALID_CHANGE_TYPES = ["CHANGE","ADD","REMOVE"]
	VALID_DATE_OPTIONS = ["Within 2 Hours", "Today", "Next Business Day", "This Week", "Specify Another Date"]
	DEFAULT_DATE = "This Week"
	attr_accessor :due_date_text
	attr_accessor :due_date_changed
	attr_accessor :status_changed
	
	validates_presence_of :status, :description, :due_date, :change_type, :current_owner, :created_by_user_id
	validates_inclusion_of :current_owner, :in => VALID_CURRENT_OWNERS
	validates_inclusion_of :status, :in => VALID_STATUSES
	validates_inclusion_of :change_type, :in => VALID_CHANGE_TYPES
	before_save :date_acceptable, :check_status
	
	belongs_to :project
	belongs_to :user
	belongs_to :creator, :class_name => "User", :foreign_key => "created_by_user_id"
	serialize :project_users, Array
	has_many :attachments, :as => :attachable
	maintain_audit_log
	
	def self.find_pending
		find(:all, :conditions => ["status NOT IN (?)",CLOSED_STATUSES])
	end

	def self.find_for_time_period(time_period)
		find :all, :conditions => "status='COMPLETE' AND updated_at > DATE_SUB(DATE(NOW()), INTERVAL 1 #{time_period})", :order => "created_at DESC"
	end
	
	def done?
		CLOSED_STATUSES.include?(status)
	end

	def other_date_specified?
		due_date_text == "Specify Another Date"
	end

	def due_date_text
		due = read_attribute(:due_date)
		unless created_at.nil?
			return "Today" if due == created_at.end_of_day
			return "Next Business Day" if due == (created_at + 1.day)
			return "This Week" if due == (created_at + 7.days)
			return "Within 2 Hours" if due == (created_at + 2.hours)
		else
			return due_date
		end
		return "Specify Another Date"
	end
	
	def due_date=(value)
		if due_date_text == "Specify Another Date" || due_date_text.nil?
			write_attribute(:due_date, value)
		end
	end
	
	def due_date_text=(value)
		@due_date_text ||= value
		if new_record? || due_date_changed || status_changed 
			if value == "Today"
				write_attribute(:due_date, Time.now.end_of_day)
			elsif value == "Next Business Day"
				write_attribute(:due_date, 1.day.from_now)
			elsif value == "This Week"
				write_attribute(:due_date, 7.days.from_now)
			elsif value == "Within 2 Hours"
				write_attribute(:due_date, 2.hours.from_now)
			else
				write_attribute(:due_date, value)
			end
		end
	end
	
	def date_acceptable
		# TODO
		# stub function for later logic dealing with 
		# business logic around dates
		true
	end

	private
	def check_status
		if status == "NEEDS MORE INFO"
			self.current_owner = "submitter"
		end
	end
	
end
