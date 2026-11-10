module SidebarHelper
  def active_group(paths)
    paths.any? { |path| path.include?(@cur_url) }
  end

  def active_item(path)
    @cur_url == path || @cur_url.start_with?("#{path}/")
  end

  def active_group_class(paths)
    active_group = active_group(paths)
    active_group ? 'active' : ''
  end

  def active_item_class(path)
    active_item = active_item(path)
    active_item ? 'active' : ''
  end
end