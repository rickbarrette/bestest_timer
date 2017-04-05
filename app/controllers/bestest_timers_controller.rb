class BestestTimersController < ApplicationController
    unloadable

    def index
        if User.current.nil?
            @user_bestest_timers = nil
            @bestest_timers = BestestTimer.all
        else
            @user_bestest_timers = BestestTimer.where(user_id: User.current.id)
            @bestest_timers = BestestTimer.where('user_id != ?', User.current.id)
        end
    end

    def start
        @bestest_timer = current
        if @bestest_timer.nil?
            @issue = Issue.find_by_id(params[:issue_id])
            @bestest_timer = BestestTimer.new({ :issue_id => @issue.id })

            if @bestest_timer.save
                apply_status_transition(@issue) unless Setting.plugin_bestest_timer['status_transitions'] == nil
                render_menu
            else
                flash[:error] = l(:start_bestest_timer_error)
            end
        else
            flash[:error] = l(:bestest_timer_already_running_error)
        end
    end

    def resume
        @bestest_timer = current
        if @bestest_timer.nil? or not @bestest_timer.paused
            flash[:error] = l(:no_bestest_timer_suspended)
            redirect_to :back
        else
            @bestest_timer.started_on = Time.now
            @bestest_timer.paused = false
            if @bestest_timer.save
                render_menu
            else
                flash[:error] = l(:resume_bestest_timer_error)
            end
        end
    end

    def suspend
        @bestest_timer = current
        if @bestest_timer.nil? or @bestest_timer.paused
            flash[:error] = l(:no_bestest_timer_running)
            redirect_to :back
        else
            @bestest_timer.time_spent = @bestest_timer.hours_spent
            @bestest_timer.paused = true
            if @bestest_timer.save
                render_menu
            else
                flash[:error] = l(:suspend_bestest_timer_error)
            end
        end
    end

    def stop
        @bestest_timer = current
        if @bestest_timer.nil?
            flash[:error] = l(:no_bestest_timer_running)
            redirect_to :back
        else
            issue_id = @bestest_timer.issue_id
            hours = @bestest_timer.hours_spent.round(2)
            @bestest_timer.destroy

            redirect_to :controller => 'issues', 
                :protocol => Setting.protocol,
                :action => 'edit', 
                :id => issue_id, 
                :time_entry => { :hours => hours }
        end
    end

    def delete
        bestest_timer = bestest_timer.find_by_id(params[:id])
        if !bestest_timer.nil?
            bestest_timer.destroy
            render :text => l(:bestest_timer_delete_success)
        else
            render :text => l(:bestest_timer_delete_fail)
        end
    end

    def render_menu
        @project = Project.find_by_id(params[:project_id])
        @issue = Issue.find_by_id(params[:issue_id])
        render :partial => 'embed_menu'
    end

    protected

    def current
        BestestTimer.find_by_user_id(User.current.id)
    end

    def apply_status_transition(issue)
        new_status_id = Setting.plugin_bestest_timer['status_transitions'][issue.status_id.to_s]
        new_status = IssueStatus.find_by_id(new_status_id)
        if issue.new_statuses_allowed_to(User.current).include?(new_status)
            journal = @issue.init_journal(User.current, notes = l(:bestest_timer_label_transition_journal))
            @issue.status_id = new_status_id
            @issue.save
        end
    end
end
