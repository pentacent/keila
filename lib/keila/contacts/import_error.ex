defmodule Keila.Contacts.ImportError do
  defexception [:message, :line, :column]
end
