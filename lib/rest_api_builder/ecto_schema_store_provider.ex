defmodule RestApiBuilder.EctoSchemaStoreProvider do
  use RestApiBuilder.Provider

  defp load_settings(opts) do
    {soft_delete_field, soft_delete_value} = Keyword.get opts, :soft_delete, {:deleted, true}
    parent_field = Keyword.get(opts, :parent, nil)

    parent_field =
      if is_binary parent_field do
        String.to_atom parent_field
      else
        parent_field
      end

    %{
      store: Keyword.get(opts, :store, nil),
      parent_field: parent_field,
      soft_delete_field: soft_delete_field,
      soft_delete_value: soft_delete_value,
      include: Keyword.get(opts, :include, []),
      exclude: Keyword.get(opts, :exclude, []),
      preload: Keyword.get(opts, :preload, []),
    }
  end

  defp append_exclude_deleted(params_list, settings) when is_list params_list do
    if has_field?(settings.soft_delete_field, settings) do
      Keyword.put params_list, settings.soft_delete_field, {:!=, settings.soft_delete_value}
    else
      params_list
    end
  end
  defp append_exclude_deleted(params, _settings), do: params

  defp has_field?(field, settings), do: field in settings.store.schema_fields

  @doc """
  Whitelist the contents of the record to be returned to only the direct fields.
  """
  def whitelist(models, opts) when is_list models do
    Enum.map models, fn(model) -> whitelist model, opts end
  end
  def whitelist(model, opts) do
    settings = load_settings opts
    keys = EctoSchemaStore.Utils.keys settings.store.schema
    include = settings.include
    exclude = settings.exclude

    keys =
      keys
      |> Enum.concat(include)
      |> Enum.reject(&(&1 in exclude))

    Map.take model, keys
  end

  def fetch_all(%Plug.Conn{assigns: %{current: parent}}, opts) do
    settings = load_settings opts
    parent_field = settings.parent_field

    if parent && parent_field do
      query =
        []
        |> append_exclude_deleted(settings)
        |> Keyword.put(parent_field, parent.id)

      settings.store.all query, preload: settings.preload 
    else
      settings.store.all append_exclude_deleted([], settings), preload: settings.preload 
    end
  end
  def fetch_all(_conn, opts) do
    settings = load_settings opts
    settings.store.all append_exclude_deleted([], settings), preload: settings.preload
  end

  @doc """
  Preload resource before handling.
  """
  def handle_preload(%Plug.Conn{path_params: %{"id" => id}, assigns: assigns} = conn, resourceModule, opts \\ []) do
    settings = load_settings opts
    parent_field = settings.parent_field
    resources = assigns[:resources]

    {parent, _href} = List.last(resources || [{nil, nil}])
    current =
      if parent && parent_field do
        query =
          [id: id]
          |> append_exclude_deleted(settings)
          |> Keyword.put(parent_field, parent.id)

        settings.store.one query, preload: settings.preload 
      else
        settings.store.one append_exclude_deleted([id: id], settings), preload: settings.preload 
      end

    validated =
      cond do
        is_nil(current) -> false
        is_nil(parent) or is_nil(parent_field) -> true
        true -> true
      end

    if validated do
      conn
      |> resourceModule.append_resource(current)
      |> Plug.Conn.assign(:parent, parent)
      |> Plug.Conn.assign(:current, current)
    else
      conn |> resourceModule.send_errors(404, "Not Found") |> Plug.Conn.halt
    end
  end

  def handle_show(conn, resourceModule, opts \\ [])
  def handle_show(conn, resourceModule, _opts) do
    case conn.assigns.current do
      nil -> resourceModule.send_errors conn, 404, "Not Found"
      model -> resourceModule.send_resource conn, resourceModule.render_view_map(model)
    end
  end

  def handle_index(conn, resourceModule, opts \\ []) do
    records = fetch_all conn, opts
    resourceModule.send_resource conn, Enum.map(records, &resourceModule.render_view_map/1)
  end

  def handle_update(%Plug.Conn{assigns: assigns} = conn, resourceModule, opts \\ []) do
    settings = load_settings opts
    current = assigns[:current]

    case current do
      nil -> resourceModule.send_errors conn, 404, "Not Found"
      model ->
        changeset = resourceModule.__use_changeset__ conn, :update
        response = settings.store.update model, conn.body_params, changeset: changeset, errors_to_map: resourceModule.singular_name()

        case response do
          {:error, message} -> resourceModule.send_errors conn, 400, message
          {:ok, record} -> resourceModule.send_resource conn, resourceModule.render_view_map(record)
        end
    end
  end

  @doc """
  Create a record.
  """
  def handle_create(%Plug.Conn{assigns: assigns} = conn, resourceModule, opts \\ []) do
    settings = load_settings opts
    parent_field = settings.parent_field
    parent = assigns[:current]
    changeset = resourceModule.__use_changeset__ conn, :create

    params =
      if parent && parent_field do
        conn.body_params
        |> Map.put(parent_field, parent.id)
      else
        conn.body_params
      end

    response = settings.store.insert params, changeset: changeset, errors_to_map: resourceModule.singular_name()

    case response do
      {:error, message} -> resourceModule.send_errors conn, 400, message
      {:ok, record} -> resourceModule.send_resource conn, resourceModule.render_view_map(record)
    end
  end

  @doc """
  Delete resource.
  """
  def handle_delete(%Plug.Conn{assigns: assigns} = conn, resourceModule, opts \\ []) do
    settings = load_settings opts
    current = assigns[:current]

    case current do
      nil -> resourceModule.send_errors conn, 404, "Not Found"
      model ->
        if has_field?(settings.soft_delete_field, settings) do
          current = assigns[:current]
          response = settings.store.update_fields(current, Keyword.put([], settings.soft_delete_field, settings.soft_delete_value), errors_to_map: resourceModule.singular_name)

          case response do
              {:error, message} -> resourceModule.send_errors conn, 400, message
              {:ok, _record} -> resourceModule.send_resource conn, nil
          end
        else
          settings.store.delete model
          resourceModule.send_resource conn, nil
        end
    end
  end

  defmacro generate(opts) do
    store = Keyword.get opts, :store, nil
    # parent_field = Keyword.get opts, :parent, nil
    # {soft_delete_field, soft_delete_value} = Keyword.get opts, :soft_delete, {:deleted, true}
    # include = Keyword.get opts, :include, []
    # exclude = Keyword.get opts, :exclude, []
    # preload = Keyword.get opts, :preload, []



    quote do
      import RestApiBuilder.EctoSchemaStoreProvider

      def store, do: unquote(store)

      # defp whitelist(models) when is_list models do
      #   Enum.map models, fn(model) -> whitelist model end
      # end
      # defp whitelist(model) do
      #   keys = EctoSchemaStore.Utils.keys unquote(store).schema
      #   include = unquote(include)
      #   exclude = unquote(exclude)

      #   keys =
      #     keys
      #     |> Enum.concat(include)
      #     |> Enum.reject(&(&1 in exclude))

      #   Map.take model, keys
      # end

      # defp fetch_all(%Plug.Conn{assigns: %{current: parent}} = conn) do
      #   parent_field = unquote(parent_field)

      #   if parent && parent_field do
      #     query =
      #       []
      #       |> append_exclude_deleted
      #       |> Keyword.put(parent_field, parent.id)

      #     unquote(store).all query, preload: unquote(preload) 
      #   else
      #     unquote(store).all append_exclude_deleted([]), preload: unquote(preload) 
      #   end
      # end
      # defp fetch_all(conn) do
      #   unquote(store).all append_exclude_deleted([]), preload: unquote(preload) 
      # end

      # defp has_field?(field), do: field in unquote(store).schema_fields

      # defp append_exclude_deleted(params_list) when is_list params_list do
      #   if has_field?(unquote(soft_delete_field)) do
      #     Keyword.put params_list, unquote(soft_delete_field), {:!=, unquote(soft_delete_value)}
      #   else
      #     params_list
      #   end
      # end
      # defp append_exclude_deleted(params), do: params

      def __use_changeset__(_, _), do: :changeset
      def render_view_map(record), do: provider().whitelist(unquote(store).to_map(record), unquote(opts))

      defoverridable [__use_changeset__: 2, render_view_map: 1]
    end
  end

  defmacro changeset(name) do
    quote do
      changeset unquote(name), :all
    end
  end

  defmacro changeset(name, :all) do
    quote do
      changeset unquote(name), [:create, :update]
    end
  end
  defmacro changeset(name, actions) when is_list actions do
    for action <- actions do
      quote do
        changeset unquote(name), unquote(action)
      end
    end
  end
  defmacro changeset(name, action) when is_binary action do
    quote do
      changeset unquote(name), String.to_atom(unquote(action))
    end
  end
  defmacro changeset(name, action) when is_binary name do
    quote do
      changeset String.to_atom(unquote(name)), unquote(action)
    end
  end
  defmacro changeset(name, action) when is_atom(action) and is_atom(name) do
    quote do
      def __use_changeset__(conn, unquote(action)) do
        override_changeset = conn.assigns[:changeset]
        override_changeset || unquote(name)
      end
    end
  end
end
