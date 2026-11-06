defmodule Runeshare.Accounts do
  use Ash.Domain, otp_app: :runeshare, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Runeshare.Accounts.Token
    resource Runeshare.Accounts.User
  end
end
