# REST API Builder - Ecto Schema Store Provider

An API resource provider for the `rest_api_builder` project. This provider allows a
developer to back a rest service using a store provided by this library.

[REST API Builder](https://hex.pm/packages/rest_api_builder)

This works is still early access may be changed significantly as that the `rest_api_builder` library is still under
initial development.

This documentation will focus on the provider itself. To see more documentation for `rest_api_builder` please visit that
project in Hex.


## Installation


```elixir
def deps do
  [{:rest_api_builder_essp, "~> 0.6"}]
end
```

## Using

```elixir
defmodule Customer do
  use EctoTest.Web, :model

  schema "customers" do
    field :name, :string
    field :email, :string
    field :account_closed, :boolean, default: false

    timestamps
  end

  def changeset(model, params) do
    model
    |> cast(params, [:name, :email])
  end
end

defmodule CustomerStore do
  use EctoSchemaStore, schema: Customer, repo: MyApp.Repo
end

defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore
end

```

## Configuring the provider

* `store`                    - The module that implements the store interface.
* `parent_field`             - The field name of the parent schema id in the Ecto schema definition. This is used when a REST API module is a child to another.
* `soft_delete`              - By default the provider will delete the record. This takes a tuple of `{field_name, value_to_set}`. When set, will update the record and exclude it from future query results.
* `include`                  - Which fields to include in the resource. By default only, non-association fields are included.
* `exclude`                  - Which fields that woudl normally be included need to be excluded from the resource output.
* `preload`                  - List of associations to preload when querying records. Dependent on need, child associations may be better as their own REST API module.

In addition, the provider also adds a command to the REST API module that allows the developer to set which changesets to use when creating or updating by default.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

   provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore,
                                                    soft_delete: {:account_closed, true},
                                                    exclude: [:account_closed]

  changeset :create_changeset, :create
  changeset :update_changeset, :update
end
```

By default, the standard name of :changset is used like normal within the store itself. To use no changeset, just provide the following:

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore,
                                                   soft_delete: {:account_closed, true},
                                                   exclude: [:account_closed]

  changeset nil
end
```

You can also provide a default changeset for both create and update:

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore,
                                                   soft_delete: {:account_closed, true},
                                                   exclude: [:account_closed]

  changeset :api_changeset
end
```

The changeset could also be changed progarmatically such as with an plug to be set based upon the using accessing the service.
This is done by adding a :changeset value to the `Plug.Conn` assigns map.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all, default_plugs: false
  import Plug.Conn

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore,
                                                   soft_delete: {:account_closed, true},
                                                   exclude: [:account_closed]

  plugs do
    plug :check_access_level
  end

  def check_access_level(%Plug.Conn{assigns: %{current_user: %{type: "admin"}}} = conn, _opts) do
    assign conn, :changeset, :admin_changeset
  end
  def check_access_level(conn, _opts), do: conn

  changeset :standard_user_changeset
end
```

## Customizing the JSON Output content ##

The generation of the final message envelope is handled by the `rest_api_builder` library. However, this library does generate the map content
that is used and set for record output. To give better control to the developer, the `render_view_map` function can be overloaded to customize
the output.

By default `render_view_map` does the following:

```elixir
 def render_view_map(record), do: whitelist(MyStore.to_map(record))
```

`whitelist` is function that filters Map content to the fields defined by the `include` and `exclude` settings of this provider. This function
can be added to your resource module in order to append or completly replace how the output map is built. You will recieve the original
Ecto model as input. This function will be applied on index, show, create, update actions. If you are defining a feature, you will need to
call this function manually.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  def render_view_map(customer) do
    customer = Map.take customer, [:name, :email]

    if customer.account_closed do
      Map.put customer, :note, "This account is closed."
    else
      Map.put customer, :note, "This account is active."
    end
  end
end
```