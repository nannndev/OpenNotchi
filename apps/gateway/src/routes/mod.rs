pub mod accounts;
pub mod admin;
pub mod providers;

use crate::engine::GatewayEngine;
use axum::{
    routing::{delete, get, patch, post, put},
    Router,
};

/// Builds the Axum router for OpenAI-compatible inference and gateway admin APIs.
pub fn gateway_router(engine: GatewayEngine) -> Router {
    Router::new()
        // Core chat completions & health
        .route("/v1/chat/completions", post(admin::handle_chat_completions))
        .route("/gateway/v1/chat/completions", post(admin::handle_chat_completions))
        .route("/v1/models", get(admin::handle_list_models_v1))
        .route("/gateway/v1/models", get(admin::handle_list_models_v1))
        .route("/gateway/health", get(admin::handle_health))
        // Accounts (OAuth)
        .route("/gateway/admin/accounts", get(accounts::handle_list_accounts).post(accounts::handle_save_account))
        .route("/gateway/admin/accounts/usage", get(accounts::handle_accounts_usage))
        .route("/gateway/admin/accounts/:provider", delete(accounts::handle_delete_account_by_query))
        .route("/gateway/admin/accounts/:provider/:id", delete(accounts::handle_remove_account))
        .route("/gateway/admin/accounts/:provider/:id/toggle", patch(accounts::handle_toggle_account))
        .route("/gateway/admin/accounts/:provider/reorder", post(accounts::handle_reorder_accounts))
        .route("/gateway/admin/accounts/:provider/start", post(accounts::handle_oauth_start))
        .route("/gateway/admin/accounts/:provider/complete", post(accounts::handle_oauth_complete))
        .route("/gateway/admin/accounts/:provider/poll", post(accounts::handle_oauth_poll))
        .route("/gateway/admin/accounts/:provider/test", post(accounts::handle_oauth_test))
        // Providers & Custom Models
        .route("/gateway/admin/providers", get(providers::handle_list_providers))
        .route("/gateway/admin/providers/:id/toggle", patch(providers::handle_toggle_provider))
        .route("/gateway/admin/providers/:id/import", post(providers::handle_import_local_key))
        .route("/gateway/admin/providers/:id/connect", post(providers::handle_connect_provider))
        .route("/gateway/admin/providers/:id/disconnect", post(providers::handle_disconnect_provider))
        .route("/gateway/admin/providers/:id/key", post(providers::handle_save_provider_key))
        .route("/gateway/admin/providers/:id/keys", post(providers::handle_add_provider_key))
        .route(
            "/gateway/admin/providers/:id/models",
            get(providers::handle_get_provider_models)
                .post(providers::handle_add_provider_model)
                .put(providers::handle_set_provider_models)
                .delete(providers::handle_delete_provider_model_body),
        )
        .route("/gateway/admin/providers/:id/models/sync", post(providers::handle_sync_provider_models))
        .route("/gateway/admin/providers/:id/models/:model", delete(providers::handle_delete_provider_model))
        // Virtual Keys
        .route("/gateway/admin/keys", get(admin::handle_list_keys).post(admin::handle_create_key))
        .route("/gateway/admin/keys/:id/toggle", patch(admin::handle_toggle_key))
        .route("/gateway/admin/keys/:id", delete(admin::handle_delete_key))
        // Combos
        .route("/gateway/admin/combos", get(admin::handle_list_combos).post(admin::handle_save_combo))
        .route("/gateway/admin/combos/:name", put(admin::handle_put_combo).delete(admin::handle_delete_combo))
        // Models, Usage, Stats, Settings
        .route("/gateway/admin/models", get(admin::handle_admin_models))
        .route("/gateway/admin/usage", get(admin::handle_list_usage).delete(admin::handle_clear_usage))
        .route("/gateway/admin/stats", get(admin::handle_get_stats))
        .route("/gateway/admin/analytics", get(admin::handle_analytics))
        .route("/gateway/admin/settings", get(admin::handle_get_settings).post(admin::handle_update_settings))
        .with_state(engine)
}
