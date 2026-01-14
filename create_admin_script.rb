
# Script to create admin user and account if missing

account = Account.first
if account
  puts "Found existing account: #{account.name} (ID: #{account.id})"
else
  puts 'No account found. Creating new account...'
  account = Account.create!(name: 'Starchat HQ')
  puts "Created account: #{account.name} (ID: #{account.id})"
end

email = 'suporte@starchats.com.br'
user = User.find_by(email: email)

if user
  puts "User #{email} already exists. Updating password..."
  user.password = 'Smvf@5353!'
  user.password_confirmation = 'Smvf@5353!'
  user.save!
  puts "Password updated."
else
  puts "Creating new user #{email}..."
  user = User.new(
    name: 'Admin',
    email: email,
    password: 'Smvf@5353!',
    password_confirmation: 'Smvf@5353!',
    type: 'SuperAdmin'
  )
  user.skip_confirmation!
  user.save!
  puts "User created."
end

# Link user to account
if AccountUser.exists?(account: account, user: user)
  puts 'User is already a member of this account.'
else
  puts 'Adding user to account as administrator...'
  AccountUser.create!(
    account: account,
    user: user,
    role: :administrator
  )
  puts "User added to account."
end

puts "\n--- Login Details ---"
puts "Email: #{email}"
puts "Password: Smvf@5353!"
