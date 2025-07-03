# Keila Project Development Insights

This document contains important insights about the Keila project structure, patterns, and conventions learned during development. This should be referenced for consistent future development.

## Project Overview
- **Type**: Elixir/Phoenix email newsletter platform
- **Architecture**: Modern Phoenix application with LiveView
- **Purpose**: Multi-tenant email marketing platform with campaigns, contacts, and analytics

## Configuration Patterns

### Environment Variable Strategy
- **Runtime Config**: Production uses `config/runtime.exs` for dynamic environment variable resolution
- **Development**: Simple hardcoded values in `config/dev.exs` and `config/test.exs`
- **URL Building**: Centralized URL configuration using:
  - `URL_HOST` - The hostname (e.g., "example.com")
  - `URL_SCHEMA` - Protocol ("http" or "https")
  - `URL_PORT` - Port number (defaults to 80/443 based on schema)
  - `URL_PATH` - Base path (defaults to "/")

### Configuration Utilities
- `maybe_to_int/1` - Safely converts strings to integers, returns nil for empty values
- `put_if_not_empty/3` - Only sets config values if they're not nil or empty
- `exit_from_exception/2` - Standardized error handling with helpful messages

### Error Handling Pattern
```elixir
try do
  # Configuration logic
rescue
  e ->
    exit_from_exception.(e, """
    Helpful error message with:
    - Required environment variables
    - Example values
    - Setup instructions
    """)
end
```

## Code Organization

### Schema Hierarchy
- **Accounts** → **Users** → **Projects** → **Campaigns/Contacts**
- Users can have multiple projects
- Projects contain campaigns and contact lists
- Proper multi-tenant isolation

### Controller Patterns
- **Admin Controllers**: Separate controllers for admin functions (e.g., `UserAdminController`)
- **Nested Resources**: Use proper Phoenix resource nesting
- **Permission Checks**: All admin functions require role verification
- **Form Separation**: Complex forms split into separate `<.form>` elements to avoid nesting

### View Helpers
- `render_icon/1` - Consistent iconography across the app
- `with_validation/2` - Form field validation display
- **Translation Keys**: Use descriptive keys like `dgettext("auth", "Two-Factor Authentication")`

## UI/UX Patterns

### CSS Framework
- **Tailwind CSS**: Primary styling framework
- **Dark Theme**: Predominantly dark UI with gray-900 backgrounds
- **Custom Classes**: 
  - `.button`, `.button--cta`, `.button--warn`, `.button--text` - Button variants
  - `.form-row` - Form field rows
  - `.form-grid` - Grid layouts (fixes margin conflicts with .form-row)

### Form Conventions
- **CSRF Tokens**: All forms must include CSRF protection
- **Validation**: Use `with_validation/2` helper for field errors
- **Accessibility**: Proper labels and form structure
- **Separation**: Avoid nested forms - split into separate form elements

### Icon Usage
- Use `render_icon/1` with semantic names like `:shield_check`, `:envelope`, `:check_circle`
- Icons should be wrapped in spans with appropriate Tailwind classes for sizing

## Database Patterns

### Migration Conventions
- **Timestamps**: Use full timestamp format (YYYYMMDDHHMMSS)
- **Descriptive Names**: Clear migration names like `add_webauthn_to_users`
- **JSON Fields**: Use `:map` type for flexible data storage (e.g., credentials)

### Schema Patterns
- **Changesets**: Separate changesets for different operations:
  - `changeset/2` - Standard user updates
  - `admin_changeset/2` - Admin-specific updates
  - `registration_changeset/2` - User registration
- **Validation**: Comprehensive validation with custom error messages
- **Associations**: Proper `has_many`/`belongs_to` relationships

## Authentication & Security

### 2FA Implementation
- **Email-based**: Default 2FA using email codes
- **WebAuthn**: Hardware security key support using `wax_` library
- **Backup Codes**: Always provide fallback authentication methods
- **Session Management**: Proper session handling for 2FA challenges

### WebAuthn Specifics
- **Library**: Uses `wax_` (note underscore due to naming conflict)
- **Configuration**: Dynamic origin building from URL components
- **JavaScript**: Client-side WebAuthn handling in templates
- **Storage**: Credentials stored as JSON in `webauthn_credentials` field

### Security Best Practices
- **CSRF Protection**: All state-changing operations protected
- **Permission Checks**: Admin operations require proper role verification
- **Input Validation**: Comprehensive validation on all user inputs
- **Secure Defaults**: WebAuthn uses "preferred" user verification

## Testing Patterns

### Test Organization
- **Controller Tests**: Comprehensive CRUD and permission testing
- **Factory Pattern**: Create test data using consistent factories
- **Authentication**: Tests include proper session and permission scenarios
- **Error Cases**: Test both success and failure scenarios

### Test Environment
- **Database**: Separate test database with partitioning support
- **Isolation**: Tests use database sandbox for isolation
- **Configuration**: Simplified config in `config/test.exs`

## Development Environment

### Container Setup
- **Dev Container**: Debian-based development environment
- **Tools**: Git, curl, wget, ssh, and other CLI tools available
- **File System**: Workspace mounted at `/workspace`

### Asset Pipeline
- **esbuild**: JavaScript bundling and compilation
- **Tailwind CSS**: CSS framework with PostCSS processing
- **Hot Reloading**: Phoenix live reload for development
- **Static Assets**: Served from `priv/static/`

## Key Dependencies

### Core Dependencies
- **Phoenix**: Web framework with LiveView
- **Ecto**: Database ORM and query interface
- **Oban**: Background job processing and scheduling
- **Swoosh**: Email sending with multiple adapters

### Authentication
- **Argon2**: Password hashing
- **Wax (`wax_`)**: WebAuthn implementation
- **Comeonin**: Password validation utilities

### UI/Frontend
- **Phoenix LiveView**: Interactive UI components
- **Tailwind CSS**: Utility-first CSS framework
- **HEEx**: Template engine for Phoenix

## Email System

### Adapters
- **Multiple Providers**: SMTP, SendGrid, SES, Mailgun, Postmark
- **Shared Adapters**: Some providers have shared configurations
- **Local Development**: Local adapter for testing
- **Background Processing**: All email sending via Oban queues

### Campaign Management
- **Scheduling**: Campaigns can be scheduled for future delivery
- **Rate Limiting**: Built-in rate limiting and quotas
- **Analytics**: Tracking and reporting capabilities

## Internationalization

### Translation Structure
- **Separate Domains**: Different `.pot` files for different areas:
  - `auth.pot` - Authentication and user management
  - `admin.pot` - Administrative interfaces
- **Key Naming**: Descriptive keys that indicate context
- **Locales**: Support for multiple languages (de, en, fr)

## Performance Considerations

### Background Processing
- **Oban Queues**: Separate queues for different job types
- **Scheduling**: Cron-based scheduling for recurring tasks
- **Monitoring**: Built-in job monitoring and retry logic

### Database
- **Connection Pooling**: Configured pool sizes for different environments
- **SSL**: Optional SSL connections with certificate verification
- **Partitioning**: Test database partitioning support

## Common Gotchas

### Form Handling
- **Nested Forms**: Phoenix doesn't support nested forms - split into separate forms
- **CSS Grid Issues**: Use `.form-grid` instead of direct `.form-row` in grid layouts
- **CSRF**: Always include CSRF tokens in AJAX requests

### Configuration
- **Environment Variables**: Production requires comprehensive environment setup
- **URL Building**: Use centralized URL configuration, don't hardcode origins
- **Error Messages**: Provide helpful error messages with setup instructions

### WebAuthn
- **Library Name**: Use `wax_` not `wax` (naming conflict)
- **Base64 Handling**: Proper base64url encoding/decoding for credentials
- **Browser Support**: Always check for WebAuthn support before using

This document should be referenced and updated as the project evolves to maintain consistency in development practices.
