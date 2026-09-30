namespace :demo_data do
  desc 'Seed Vietnamese demo data into an account without touching existing data. Usage: ACCOUNT_ID=1 rake demo_data:seed'
  task seed: :environment do
    account = Account.find(ENV.fetch('ACCOUNT_ID'))
    Seeders::DemoAccountSeeder.new(account: account).seed!
    puts "Demo data created for account #{account.id} (#{account.name})"
  end

  desc 'Remove the demo data created by demo_data:seed. Usage: ACCOUNT_ID=1 rake demo_data:clear'
  task clear: :environment do
    account = Account.find(ENV.fetch('ACCOUNT_ID'))
    Seeders::DemoAccountSeeder.new(account: account).clear!
    puts "Demo data removed from account #{account.id} (#{account.name})"
  end
end
