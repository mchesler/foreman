module Authorization
  extend ActiveSupport::Concern

  included do
    before_save    :enforce_edit_permissions
    before_destroy :enforce_destroy_permissions
    before_create  :enforce_create_permissions
  end

  # We must enforce the security model
  def enforce_edit_permissions
    enforce_permissions("edit") if enforce?
  end

  def enforce_destroy_permissions
    enforce_permissions("destroy") if enforce?
  end

  def enforce_create_permissions
    enforce_permissions("create") if enforce?
  end

  def enforce_permissions operation
    # We get called again with the operation being set to create
    return true if operation == "edit" and new_record?

    if self.class < Operatingsystem
      klass = 'operatingsystem'
      klasses   = 'operatingsystems'
    else
      klass   = self.class.name.downcase
      klasses   = self.class.name.tableize
    end

    #TODO: Extract all fo the specific implementations into each individual class
    klasses.gsub!(/auth_source.*/, "authenticators")
    klasses.gsub!(/common_parameters.*/, "global_variables")
    klasses.gsub!(/lookup_key.*/, "external_variables")
    klasses.gsub!(/lookup_value.*/, "external_variables")
    # editing own user is a special case
    if User.current
      action = if klass == 'user'
                 { :controller => 'users', :action => operation, :id => self.id }
               else
                 "#{operation}_#{klasses}".to_sym
               end
      return true if User.current.allowed_to?(action)
    end

    errors.add :base, _("You do not have permission to %{operation} this %{klass}") % { :operation => operation, :klass => klass }
    @permission_failed = operation
    false
  end

  # @return false or name of failed operation
  def permission_failed?
    return false unless @permission_failed
    @permission_failed
  end

  private
  def enforce?
    return false if (User.current and User.current.admin?)
    return true  if defined?(Rake) and Rails.env == "test"
    return false if defined?(Rake)
    true
  end
end
