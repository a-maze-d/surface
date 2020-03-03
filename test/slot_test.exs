defmodule SlotTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "stateful")
      ~H"""
      <div>Stateful</div>
      """
    end
  end

  defmodule InnerData do
    use Surface.Slot, name: "inner"

    property label, :string
  end

  defmodule Outer do
    use Surface.LiveComponent

    slot default
    slot inner

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "outer")

      ~H"""
      <div>
        <div :for={{ data <- @inner }}>
          {{ data.label }}: {{ data.inner_content.() }}
        </div>
        <div>
          {{ @inner_content.() }}
        </div>
      </div>
      """
    end
  end

  defmodule Column do
    use Surface.Slot, name: "cols"

    property title, :string, required: true
  end

  defmodule Grid do
    use Surface.LiveComponent

    property items, :list, required: true

    slot cols, args: [:info, item: ^items]

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "table")
      info = "Some info from Grid"
      ~H"""
      <table>
        <tr>
          <th :for={{ col <- @cols }}>
            {{ col.title }}
          </th>
        </tr>
        <tr :for={{ item <- @items }}>
          <td :for={{ col <- @cols }}>
            {{ col.inner_content.(item: item, info: info) }}
          </td>
        </tr>
      </table>
      """
    end
  end

  test "render inner content with no bindings" do
    code =
      """
      <Outer>
        Content 1
        <InnerData label="label 1">
          <b>content 1</b>
          <StatefulComponent id="stateful1"/>
        </InnerData>
        Content 2
          Content 2.1
        <InnerData label="label 2">
          <b>content 2</b>
        </InnerData>
        Content 3
        <StatefulComponent id="stateful2"/>
      </Outer>
      """

    assert_html render_live(code) =~ """
    <div surface-cid="outer">
      <div>
        label 1:<b>content 1</b>
        <div surface-cid="stateful" data-phx-component="0">Stateful</div>
      </div>
      <div>
        label 2:<b>content 2</b>
      </div>
      <div>
        Content 1
        Content 2
          Content 2.1
        Content 3
        <div surface-cid="stateful" data-phx-component="1">Stateful</div>
      </div>
    </div>
    """
  end

  test "render inner content with parent bindings" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID">
          <b>Id: {{ user.id }}</b>
        </Column>
        <Column title="NAME">
          Name: {{ user.name }}
        </Column>
      </Grid>
      """

    assert_html render_live(code, assigns) =~ """
    <table surface-cid="table">
      <tr>
        <th>ID</th><th>NAME</th>
      </tr><tr>
        <td><b>Id: 1</b></td>
        <td>Name: First</td>
      </tr><tr>
        <td><b>Id: 2</b></td>
        <td>Name: Second</td>
      </tr>
    </table>
    """
  end

  test "render inner content renaming args" do
    assigns = %{items: [%{id: 1, name: "First"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID" :bindings={{ item: my_user }}>
          <b>Id: {{ my_user.id }}</b>
        </Column>
        <Column title="NAME" :bindings={{ info: my_info }}>
          Name: {{ user.name }}
          Info: {{ my_info }}
        </Column>
      </Grid>
      """

    assert_html render_live(code, assigns) =~ """
    <table surface-cid="table">
      <tr>
        <th>ID</th><th>NAME</th>
      </tr><tr>
        <td><b>Id: 1</b></td>
        <td>Name: First
        Info: Some info from Grid</td>
      </tr>
    </table>
    """
  end

  test "raise compile error for undefined bindings" do
    assigns = %{items: [%{id: 1, name: "First"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID" :bindings={{ item: my_user, non_existing1: 1, non_existing2: 2 }}>
          <b>Id: {{ my_user.id }}</b>
        </Column>
      </Grid>
      """

    message = """
    code:2: undefined slot variable. Expected any of [:item, :info], got: \
    [:item, :non_existing1, :non_existing2].
    Hint: Define all accepted variables of the slot using the :args option, \
    e.g. `slot slot_name, args: [:arg1, :arg2]\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "raise compile error when no slot name is defined" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestSlotWithoutSlotName_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Slot

      property label, :string
    end
    """

    message = "code.exs:2: slot name is required. Usage: use Surface.Slot, name: ..."

    assert_raise(CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end
end