use leptos::prelude::*;
use leptos_meta::Style;

turf::style_sheet!("style/header.scss");

/// Renders the home page of your application.
#[component]
pub fn HomePage() -> impl IntoView {
  // Creates a reactive value to update the button
  let count = RwSignal::new(0);
  let on_click = move |_| *count.write() += 1;

  view! {
      <div class={ClassName::TEST}>
      <h1>"Welcome to Leptos!"</h1>
      <button on:click=on_click>"Click Me: " {count}</button>
      </div>
  }
}
