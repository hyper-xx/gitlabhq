module TodosHelper
  def todos_pending_count
    current_user.todos.pending.count
  end

  def todos_done_count
    current_user.todos.done.count
  end

  def todo_action_name(todo)
    case todo.action
    when Todo::ASSIGNED then 'assigned you'
    when Todo::MENTIONED then 'mentioned you on'
    when Todo::BUILD_FAILED then 'The build failed for your'
    end
  end

  def todo_target_link(todo)
    target = todo.target_type.titleize.downcase
    link_to "#{target} #{todo.target_reference}", todo_target_path(todo), { title: todo.target.title }
  end

  def todo_target_path(todo)
    return unless todo.target.present?

    anchor = dom_id(todo.note) if todo.note.present?

    if todo.for_commit?
      namespace_project_commit_path(todo.project.namespace.becomes(Namespace), todo.project,
                                    todo.target, anchor: anchor)
    else
      path = [todo.project.namespace.becomes(Namespace), todo.project, todo.target]

      path.unshift(:builds) if todo.build_failed?

      polymorphic_path(path, anchor: anchor)
    end
  end

  def todos_filter_params
    {
      state:      params[:state],
      project_id: params[:project_id],
      author_id:  params[:author_id],
      type:       params[:type],
      action_id:  params[:action_id],
    }
  end

  def todos_filter_path(options = {})
    without = options.delete(:without)

    options = todos_filter_params.merge(options)

    if without.present?
      without.each do |key|
        options.delete(key)
      end
    end

    path = request.path
    path << "?#{options.to_param}"
    path
  end

  def todo_actions_options
    actions = [
      OpenStruct.new(id: '', title: '任何动作'),
      OpenStruct.new(id: Todo::ASSIGNED, title: '被指派'),
      OpenStruct.new(id: Todo::MENTIONED, title: '被提及')
    ]

    options_from_collection_for_select(actions, 'id', 'title', params[:action_id])
  end

  def todo_projects_options
    projects = current_user.authorized_projects.sorted_by_activity.non_archived
    projects = projects.includes(:namespace)

    projects = projects.map do |project|
      OpenStruct.new(id: project.id, title: project.name_with_namespace)
    end

    projects.unshift(OpenStruct.new(id: '', title: '任何项目'))

    options_from_collection_for_select(projects, 'id', 'title', params[:project_id])
  end

  def todo_types_options
    types = [
      OpenStruct.new(title: '任何类型', name: ''),
      OpenStruct.new(title: '问题', name: 'Issue'),
      OpenStruct.new(title: '合并请求', name: 'MergeRequest')
    ]

    options_from_collection_for_select(types, 'name', 'title', params[:type])
  end
end
