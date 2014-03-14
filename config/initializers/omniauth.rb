no_providers = <<-EOM
config/auth.yml not found.  No external authentication providers will be
available.  Please see config/auth.yml.sample for direction.
EOM

Rails.application.config.middleware.use OmniAuth::Builder do
  auth_path = File.join(File.dirname(__FILE__), '..', 'auth.yml')

  $scirate_omniauth_providers = []

  if not File.exists?(auth_path)
    puts no_providers
  else

    YAML.parse(File.read(auth_path)).to_ruby.each do |name, config|
      provider name, *config
      $scirate_omniauth_providers << name
    end

    if $scirate_omniauth_providers.length == 0
      puts no_providers
    end
  end
end
