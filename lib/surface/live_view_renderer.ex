defmodule Surface.LiveViewRenderer do
  alias Surface.Properties

  def render_code(%{children: []} = node, caller) do
    %{name: mod_str, attributes: attributes, module: mod} = node
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["<%= ", "Surface.LiveViewRenderer.render(@socket, ", mod_str, ", session: %{props: ", rendered_props, "})", " %>"]
  end

  def render(socket, module, opts) do
    do_render(socket, module, opts, [])
  end

  def render(socket, module, opts, do: block) do
    do_render(socket, module, opts, block)
  end

  def do_render(socket, module, opts, content) do
    opts = put_in(opts, [:session, :props, :content], content)
    Phoenix.LiveView.live_render(socket, module, opts)
  end
end
