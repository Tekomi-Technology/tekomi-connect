# Bản đồ: Hội thoại

> Lập tại commit `c37c7293a9` — ngày 2026-10-03
> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Mảng Hội thoại là trục chính của Tekomi Connect: mỗi `Conversation` gắn một `Contact` với một `Inbox` qua `ContactInbox`, chứa các `Message`, và mang trạng thái (`open`/`resolved`/`pending`/`snoozed`), độ ưu tiên, người/đội phụ trách, nhãn và thuộc tính tuỳ biến. Giao diện gồm hai nửa: danh sách bên trái (`ChatList.vue` → `ConversationList.vue`) và khung chi tiết bên phải (`ConversationBox.vue` → `MessagesView.vue` + `ReplyBox.vue`), kèm panel phụ `ConversationSidebar.vue` → `ContactPanel.vue`. Dữ liệu danh sách đi qua hai đường riêng biệt: `ConversationFinder` (lọc đơn giản theo tab/inbox/team/label) và `Conversations::FilterService` (lọc nâng cao + thư mục/custom views). Thời gian thực được đẩy qua ActionCable (`ActionCableListener`) và cập nhật trực tiếp vào Vuex module `conversations`. Lớp phủ Enterprise bổ sung SLA (`AppliedSla`, `SlaEvent`), phân tích hội thoại, voice call và trợ lý Tekomi.

## Database

| Bảng | Vai trò | Cột đáng chú ý |
|---|---|---|
| `conversations` | Bản ghi hội thoại chính | `account_id`, `inbox_id`, `contact_id`, `contact_inbox_id`, `display_id` (ID hiển thị, UNIQUE theo account, do DB trigger `nextval('conv_dpid_seq_<account_id>')` sinh), `uuid`, `status` (enum 0 open/1 resolved/2 pending/3 snoozed), `priority` (0 low…3 urgent), `assignee_id`, `assignee_agent_bot_id` + `ai_assignee_type` (assignee đa hình), `team_id`, `campaign_id`, `sla_policy_id`, `snoozed_until`, `waiting_since`, `first_reply_created_at`, `last_activity_at`, `status_changed_at`, `agent_last_seen_at`, `assignee_last_seen_at`, `contact_last_seen_at`, `cached_label_list` (text, danh sách nhãn dạng CSV), `additional_attributes` (jsonb), `custom_attributes` (jsonb), `identifier` |
| `messages` | Tin nhắn thuộc hội thoại | `conversation_id`, `inbox_id`, `account_id`, `message_type` (incoming/outgoing/activity/template), `content_type` (14 giá trị, gồm `voice_call`, `phone_call`, `input_csat`…), `private`, `status` (sent/delivered/read/failed), `content_attributes` (json store), `external_source_ids`, `sender_type`/`sender_id`, `sentiment` |
| `taggings` + `tags` | Nhãn hội thoại (acts-as-taggable-on) | `taggings.taggable_type`/`taggable_id`/`context` (`labels`), `tags.name` |
| `labels` | Định nghĩa nhãn của account | `title` (UNIQUE theo account, tự lowercase), `color`, `show_on_sidebar` |
| `conversation_participants` | Người theo dõi hội thoại | UNIQUE `(user_id, conversation_id)` |
| `mentions` | Nhắc tên agent trong note riêng | `conversation_id`, `user_id`, `mentioned_at`, UNIQUE theo `(user, conversation)` |
| `custom_filters` | Thư mục / bộ lọc đã lưu | `filter_type` (enum 0 conversation/1 contact/2 report), `query` (jsonb), `user_id` |
| `macros` | Macro thao tác nhanh | `actions` (jsonb), `visibility` (0 personal/1 global), `created_by_id`, `updated_by_id`, có `has_many_attached :files` |
| `sla_policies` | Chính sách SLA (Enterprise) | `first_response_time_threshold`, `next_response_time_threshold`, `resolution_time_threshold`, `only_during_business_hours` |
| `applied_slas` | SLA áp vào 1 hội thoại (Enterprise) | `sla_status` (active/hit/missed/active_with_misses), `completed_at`, UNIQUE `(account_id, sla_policy_id, conversation_id)` |
| `sla_events` | Mốc vi phạm SLA (Enterprise) | `event_type` (frt/nrt/rt), `meta` (jsonb), `applied_sla_id`, `conversation_id`, `inbox_id` |
| `deal_conversations`, `ticket_conversations` | Bảng nối hội thoại ↔ deal/ticket (CRM) | `conversation_id` + `deal_id`/`ticket_id` |
| `reporting_events`, `csat_survey_responses`, `notifications`, `automation_rule_pending_executions` | Bảng phụ thuộc trỏ về `conversation_id` | — |

## Backend

| File | Vai trò |
|---|---|
| `app/models/conversation.rb` | Model chính: enum status/priority, scope (`unassigned`, `assigned`, `assigned_to`, `unattended`, `resolvable_not_waiting`, `resolvable_all`, `sort_on_unread`), callback dispatch event, `toggle_status`, `toggle_priority`, `bot_handoff!`, `unread_messages`, `can_reply?`, DB trigger sinh `display_id` |
| `app/models/concerns/assignment_handler.rb` | Đảm bảo assignee thuộc team, bắn `ASSIGNEE_CHANGED`/`TEAM_CHANGED`, tạo activity message |
| `app/models/concerns/auto_assignment_handler.rb` | Tự động phân công (V1 legacy trong `before_save`, V2 qua `AutoAssignment::AssignmentJob.enqueue_for_inbox`) |
| `app/models/concerns/sort_handler.rb` | Các `sort_on_*` dùng bởi `ConversationFinder` và `FilterService` |
| `app/models/concerns/labelable.rb` | `acts_as_taggable_on :labels`, `add_labels`, `update_labels` (dùng chung với `Contact`) |
| `app/models/concerns/conversation_mute_helpers.rb` | `mute!` → resolve hội thoại **và** set `contact.blocked = true`; `unmute!` ngược lại |
| `app/models/concerns/push_data_helper.rb` | `push_event_data` / `webhook_data` / `lock_event_data` |
| `app/models/concerns/activity_message_handler.rb` + `assignee_/label_/priority_/team_/sla_activity_message_handler.rb` | Sinh message `activity` khi đổi trạng thái/assignee/nhãn/priority/team/SLA |
| `app/models/message.rb` | Model tin nhắn |
| `app/models/conversation_participant.rb`, `app/models/mention.rb` | Participant & mention |
| `app/models/custom_filter.rb` | Thư mục/bộ lọc đã lưu; giới hạn `Limits::MAX_CUSTOM_FILTERS_PER_USER`; invalidate cache unread đã lọc |
| `app/models/macro.rb` | Macro; whitelist 16 action trong `ACTIONS_ATTRS`; `with_visibility` (global + personal của user) |
| `app/models/label.rb` | Nhãn; `after_update_commit :update_associated_models` để đổi tên nhãn lan sang conversation/contact |
| `app/finders/conversation_finder.rb` | Nguồn dữ liệu cho `index`/`meta`/`search`; `SORT_OPTIONS`, đếm `mine/assigned/unassigned/all/vip`, ưu tiên VIP đang chờ lên đầu |
| `app/services/filter_service.rb` | Lớp cơ sở xây query từ payload filter, đọc `lib/filters/filter_keys.yml` |
| `app/services/conversations/filter_service.rb` | Lọc nâng cao cho hội thoại (`POST /filter`), có "plan hint" khi lọc theo label |
| `app/services/conversations/permission_filter_service.rb` | Giới hạn hội thoại theo inbox mà user là thành viên (admin thấy tất cả); có nhánh `inbox_id + 0` để lừa planner (CW-7787) |
| `app/services/conversations/assignment_service.rb` | Gán agent hoặc agent bot, khoá row bằng `with_lock` |
| `app/services/conversations/message_window_service.rb` | Quyết định `can_reply?` theo kênh (24h WhatsApp, 48h TikTok, cấu hình API…) |
| `app/services/conversations/typing_status_manager.rb` | Bật/tắt trạng thái đang gõ |
| `app/services/conversations/delete_service.rb` | Xoá hội thoại qua `DeleteObjectJob`, ghi nhận message email đã xoá |
| `app/services/conversations/unread_counts/*` | Bộ đếm chưa đọc theo inbox/label/team và theo bộ lọc (`Counter`, `Builder`, `FilteredCounter`, `FilteredCountInvalidator`, `Notifier`, `Refresher`, `Store`…) |
| `app/services/action_service.rb` | Tập hành động dùng chung cho Macro **và** Automation (`change_status`, `add_label`, `assign_agent`, `snooze_conversation`…) |
| `app/services/macros/execution_service.rb` | Chạy macro trên 1 hội thoại (kế thừa `ActionService`) |
| `app/builders/conversation_builder.rb` | Tạo hội thoại mới hoặc trả về hội thoại cũ nếu inbox `lock_to_single_conversation?` |
| `app/builders/messages/message_builder.rb` | Tạo tin nhắn |
| `app/presenters/conversations/event_data_presenter.rb` | Payload cho ActionCable/webhook |
| `app/policies/conversation_policy.rb` | `index?` luôn true; `show?` = admin \|\| agent bot \|\| có quyền inbox/team; **`destroy?` chỉ admin** |
| `app/policies/custom_filter_policy.rb`, `app/policies/macro_policy.rb`, `app/policies/label_policy.rb` | Phân quyền thư mục, macro, nhãn |
| `app/jobs/conversations/reopen_snoozed_conversations_job.rb` | Mở lại hội thoại `snoozed` có `snoozed_until` trong khoảng `3.days.ago..now` |
| `app/jobs/conversations/resolution_job.rb` | Tự động resolve theo `account.auto_resolve_after`, giới hạn `Limits::BULK_ACTIONS_LIMIT` |
| `app/jobs/conversations/activity_message_job.rb`, `update_message_status_job.rb`, `user_mention_job.rb` | Job phụ |
| `app/jobs/bulk_actions_job.rb` | Thao tác hàng loạt (status, assignee, team, nhãn thêm/bớt, snooze) |
| `app/jobs/macros_execution_job.rb` | Chạy macro trên nhiều hội thoại |
| `app/listeners/action_cable_listener.rb` | Phát `conversation.created/updated/read/status_changed/typing_*/unread_count_changed` tới token user của inbox + contact |
| `app/listeners/automation_rule_listener.rb` | Chạy automation theo event hội thoại |
| `app/listeners/reporting_event_listener.rb` | Ghi `reporting_events` khi resolve / first reply |
| `app/listeners/notification_listener.rb`, `participation_listener.rb`, `webhook_listener.rb`, `hook_listener.rb`, `csat_survey_listener.rb` | Thông báo, participant, webhook, CSAT |
| `app/controllers/api/v1/accounts/conversations_controller.rb` | Controller chính (xem bảng API) |
| `app/controllers/api/v1/accounts/conversations/{assignments,labels,messages,participants,draft_messages,direct_uploads,deals,tickets,crm_tickets,unread_counts,base}_controller.rb` | Các endpoint lồng |
| `app/controllers/api/v1/accounts/custom_filters_controller.rb` | CRUD thư mục/bộ lọc đã lưu (scope theo `Current.user`) |
| `app/controllers/api/v1/accounts/macros_controller.rb` | CRUD + `execute` macro |
| `app/controllers/api/v1/accounts/bulk_actions_controller.rb` | Thao tác hàng loạt |
| `app/controllers/concerns/conversation_custom_attributes_concern.rb` | `custom_attributes` / `destroy_custom_attributes` (có cờ `merge`) |
| `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` | Payload JSON chuẩn của 1 hội thoại (gọi thêm partial Enterprise cho SLA) |
| `lib/filters/filter_keys.yml` | Khai báo attribute/operator cho filter hội thoại, contact và automation |
| `lib/events/types.rb` | Hằng tên event (`CONVERSATION_CREATED`, `CONVERSATION_UPDATED`, …) |
| **Enterprise** | |
| `enterprise/app/models/enterprise/conversation.rb` | `prepend` vào `Conversation`: thêm `sla_policy_id` vào danh sách key phát event, rebroadcast khi `call_status`/`call_direction` đổi, `determine_conversation_status` theo trợ lý Tekomi, cập nhật `applied_sla.completed_at` khi resolve |
| `enterprise/app/models/enterprise/concerns/conversation.rb` | `include`: quan hệ `sla_policy`/`applied_sla`/`sla_events`/`calls`/`conversation_analysis`/`conversation_outcomes`, validate SLA, `around_save :ensure_applied_sla_is_created` |
| `enterprise/app/models/{applied_sla,sla_policy,sla_event}.rb` | Model SLA |
| `enterprise/app/services/sla/evaluate_applied_sla_service.rb` | Kiểm tra FRT/NRT/RT, chuyển `sla_status` |
| `enterprise/app/jobs/sla/{trigger_slas_for_accounts_job,process_account_applied_slas_job,process_applied_sla_job}.rb` | Chuỗi job quét SLA định kỳ |
| `enterprise/app/controllers/enterprise/api/v1/accounts/conversations_controller.rb` | Thêm `inbox_assistant`, `reporting_events`, cho phép `sla_policy_id` trong `update` khi feature `sla` bật |
| `enterprise/app/controllers/api/v1/accounts/conversations/analyses_controller.rb` | Phân tích hội thoại bằng AI |
| `enterprise/app/views/enterprise/api/v1/conversations/partials/_conversation.json.jbuilder` | Thêm `applied_sla` + `sla_events` vào payload |

## API / Route

Khai báo tại `config/routes.rb` (dòng ~174–218), namespace `/api/v1/accounts/:account_id`.

| Method + đường dẫn | Controller#action | Ghi chú |
|---|---|---|
| `GET /conversations` | `conversations#index` | Qua `ConversationFinder`; params: `inbox_id`, `team_id`, `status`, `assignee_type`, `page`, `labels`, `conversation_type`, `sort_by`, `updated_within`, `source_id`. Trả `{ data: { meta, payload } }` |
| `GET /conversations/meta` | `conversations#meta` | Chỉ trả bộ đếm (`perform_meta_only`) |
| `GET /conversations/search` | `conversations#search` | `ConversationFinder` với `params[:q]` (ILIKE trên `messages.content`) |
| `POST /conversations/filter` | `conversations#filter` | `Conversations::FilterService`; trả `{ meta, payload }` **không bọc `data`** |
| `GET /conversations/unread_counts` | `conversations/unread_counts#index` | Chặn nếu account chưa bật `conversation_unread_counts` (403) |
| `POST /conversations` | `conversations#create` | Qua `ConversationBuilder`, có thể kèm `message` |
| `GET /conversations/:id` | `conversations#show` | `:id` là `display_id`, không phải PK |
| `PATCH/PUT /conversations/:id` | `conversations#update` | Chỉ permit `:priority` (Enterprise thêm `:sla_policy_id` khi bật `sla`) |
| `DELETE /conversations/:id` | `conversations#destroy` | `authorize :destroy?` → **chỉ admin** |
| `POST /conversations/:id/toggle_status` | `conversations#toggle_status` | Có nhánh `bot_handoff?` khi caller là `AgentBot`; agent mở hội thoại sẽ tự nhận (`handle_human_open`) |
| `POST /conversations/:id/toggle_priority` | `conversations#toggle_priority` | |
| `POST /conversations/:id/toggle_typing_status` | `conversations#toggle_typing_status` | |
| `POST /conversations/:id/update_last_seen` | `conversations#update_last_seen` | Có throttle 1 giờ khi không có tin chưa đọc |
| `POST /conversations/:id/unread` | `conversations#unread` | Đặt `last_seen` = trước tin incoming cuối 1 giây |
| `POST /conversations/:id/mute` / `unmute` | `conversations#mute` / `#unmute` | **Mute = resolve + block contact** |
| `POST /conversations/:id/transcript` | `conversations#transcript` | Cần `account.email_transcript_enabled?` + rate limit email |
| `POST /conversations/:id/external_ticket` | `conversations#external_ticket` | Đẩy sang Perfex CRM |
| `POST /conversations/:id/custom_attributes` | `conversations#custom_attributes` | Mặc định **ghi đè**; `merge=true` để trộn |
| `POST /conversations/:id/destroy_custom_attributes` | `conversations#destroy_custom_attributes` | |
| `GET /conversations/:id/attachments` | `conversations#attachments` | 100 bản ghi/trang |
| `GET /conversations/:id/inbox_assistant` | `conversations#inbox_assistant` | Enterprise overlay |
| `GET /conversations/:id/reporting_events` | `conversations#reporting_events` | Chỉ khi `ChatwootApp.enterprise?` |
| `GET/POST/PATCH/DELETE /conversations/:conversation_id/messages[/:id]` | `conversations/messages#*` | Thêm `POST .../translate`, `POST .../retry` |
| `POST /conversations/:conversation_id/assignments` | `conversations/assignments#create` | `assignee_id` (+ `assignee_type=AgentBot`) hoặc `team_id` |
| `GET/POST /conversations/:conversation_id/labels` | `conversations/labels#index`/`#create` | |
| `GET/POST/PATCH/DELETE /conversations/:conversation_id/participants` | `conversations/participants#*` | Chặn user không có quyền inbox |
| `GET/PATCH/DELETE /conversations/:conversation_id/draft_messages` | `conversations/draft_messages#*` | |
| `POST /conversations/:conversation_id/direct_uploads` | `conversations/direct_uploads#create` | |
| `GET /conversations/:conversation_id/{deals,tickets,crm_tickets}` | tương ứng | CRM |
| `GET/POST /conversations/:conversation_id/analysis`, `POST .../analysis/care_suggestion` | `conversations/analyses#*` | Chỉ Enterprise |
| `GET /search/conversations` | `search#conversations` | Tìm kiếm toàn cục (`SearchService`) |
| `GET /contacts/:contact_id/conversations` | `contacts/conversations#index` | Lịch sử hội thoại của contact |
| `GET /companies/:company_id/conversations` | `companies/conversations#index` | Chế độ hiển thị theo công ty |
| `GET /deals/:deal_id/conversations`, `POST`, `DELETE` | `deals/conversations#*` | Gắn/bỏ gắn hội thoại vào deal |
| `GET/POST/PATCH/DELETE /custom_filters[/:id]` | `custom_filters#*` | Thư mục; `filter_type=conversation` là mặc định |
| `GET/POST/PATCH/DELETE /macros[/:id]`, `POST /macros/:id/execute` | `macros#*` | |
| `POST /bulk_actions` | `bulk_actions#create` | `type=Conversation` → `BulkActionsJob` |
| `GET/POST/PATCH/DELETE /sla_policies[/:id]` | `sla_policies#*` | |

## Frontend

| File | Vai trò |
|---|---|
| `app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js` | 18 route dùng chung component `ConversationView`: `home`, `inbox_conversation`, `inbox_dashboard`, `conversation_through_inbox`, `label_conversations`, `conversations_through_label`, `team_conversations`, `conversations_through_team`, `folder_conversations`, `conversations_through_folders`, `conversation_mentions`, `conversation_unattended`, `conversation_participating` + biến thể `.../:conversationId`. Có `beforeEnter` kiểm tra thư mục còn tồn tại |
| `.../conversation/ConversationView.vue` | Khung 3 cột: `ChatList` + `ConversationBox` + `ConversationSidebar`; quản lý layout mở rộng/thu gọn, `clearSelectedState` khi rời route |
| `app/javascript/dashboard/components/ChatList.vue` | Bộ não danh sách: tab assignee, display mode, status/sort filter, filter nâng cao, thư mục, bulk actions, context menu, phân trang; `provide()` các hành động cho card con |
| `app/javascript/dashboard/components/ChatListHeader.vue`, `ConversationList.vue`, `ConversationItem.vue`, `CompanyConversationList.vue` | Header, danh sách ảo hoá (`virtua`), item, danh sách theo công ty |
| `app/javascript/dashboard/components/widgets/ChatTypeTabs.vue` | Tab Me / Unassigned / All |
| `app/javascript/dashboard/components-next/Conversation/ConversationDisplayMode.vue` | Chọn chế độ hiển thị (default / company / vip) |
| `app/javascript/dashboard/components-next/Conversation/ConversationCard/*` | Card hội thoại thế hệ mới: `ConversationCard.vue`, `ConversationCardExpanded.vue`, `CardLabels.vue`, `CardPriorityIcon.vue`, `CardStatusIcon.vue`, `SLACardLabel.vue`, `UnreadBadge.vue` |
| `app/javascript/dashboard/components-next/Conversation/{SidepanelSwitch,SidePanelTransition,SidePanelShell,ConversationListToggle,InboxName}.vue` | Điều khiển panel/khung |
| `app/javascript/dashboard/components-next/filter/ConversationFilter.vue`, `SaveCustomView.vue` | Modal lọc nâng cao & lưu thành thư mục |
| `app/javascript/dashboard/routes/dashboard/customviews/DeleteCustomViews.vue` | Xoá thư mục |
| `app/javascript/dashboard/components/widgets/conversation/ConversationBox.vue` | Khung chi tiết: header + tab dashboard app + `MessagesView` |
| `.../conversation/ConversationHeader.vue`, `MessagesView.vue`, `ReplyBox.vue`, `MoreActions.vue`, `MacroList.vue`, `EmailTranscriptModal.vue`, `OlderConversationBar.vue`, `ZaloSessionBanner.vue`, `ReplyBoxBanner.vue` | Thanh tiêu đề, luồng tin nhắn, hộp trả lời và phụ trợ |
| `.../conversation/conversationBulkActions/Index.vue` | Thao tác hàng loạt |
| `.../conversation/contextMenu/`, `advancedFilterItems/` | Context menu card và khai báo thuộc tính lọc (`index.js`, `languages.js`) |
| `app/javascript/dashboard/components/widgets/conversation/ConversationSidebar.vue` | Vỏ panel bên phải, 4 tab (contact / actions / history / sales) + tab Company |
| `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` | Nội dung panel; sắp xếp section kéo-thả theo `conversation_sidebar_items_order` |
| `.../conversation/{ConversationAction,ConversationInfo,ConversationParticipant,ContactConversations,SharedFiles,ContactDetailsItem}.vue` | Các section: đổi assignee/team/priority/nhãn, thông tin hội thoại, participant, hội thoại trước, file đã chia sẻ |
| `.../conversation/labels/LabelBox.vue`, `customAttributes/CustomAttributes.vue`, `Macros/{List,MacroItem,MacroPreview}.vue` | Nhãn, thuộc tính tuỳ biến, macro trong panel |
| `.../conversation/contact/{ContactInfo,ContactForm,EditContact,ContactNotes,ViewAllConversations}.vue` | Khối thông tin contact trong panel |
| `app/javascript/dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue` | Modal bắt buộc điền thuộc tính trước khi resolve |
| `app/javascript/dashboard/store/modules/conversations/{index,actions,getters,helpers}.js` | Vuex module `conversations`: state `allConversations`, `selectedChatId`, `appliedFilters`, `conversationFilters`; ~46 action; mutation xử lý realtime |
| `.../conversations/actions/{messageReadActions,messageTranslateActions}.js` | Đánh dấu đã đọc / chưa đọc, dịch tin nhắn |
| `.../conversations/helpers/{actionHelpers,filterHelpers}.js` | `buildConversationList`, nhận diện view hiện tại, `matchesFilters` (lọc lại ở client) |
| `app/javascript/dashboard/store/modules/{conversationStats,conversationPage,conversationMetadata,conversationLabels,conversationSearch,conversationTypingStatus,conversationUnreadCounts,conversationWatchers,contactConversations,customViews,macros,labels,sla,draftMessages}.js` | Các module phụ trợ của mảng |
| `app/javascript/dashboard/api/inbox/conversation.js` | API client chính (get/filter/search/toggleStatus/togglePriority/assignAgent/assignTeam/markMessageRead/markMessagesUnread/toggleTyping/mute/unmute/meta/transcript/customAttributes/participants/attachments/delete) |
| `app/javascript/dashboard/api/conversations.js` | Client phụ (labels, `unread_counts`) |
| `app/javascript/dashboard/api/{customViews,macros,labels,sla}.js` | Client thư mục, macro, nhãn, SLA |
| `app/javascript/dashboard/composables/useConversationSidePanel.js` | Khai báo 4 panel và section thuộc mỗi panel |
| `app/javascript/dashboard/composables/useUISettings.js` | `DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER` (13 section), đọc/ghi UI settings |
| `app/javascript/dashboard/composables/useConversationRequiredAttributes.js` | Kiểm tra thuộc tính bắt buộc trước khi resolve |
| `app/javascript/dashboard/composables/useConversationRoutePath.js`, `chatlist/useBulkActions.js`, `chatlist/useChatListKeyboardEvents.js`, `useContactConversationNavigation.js` | Điều hướng, bulk action, phím tắt danh sách |
| `app/javascript/dashboard/constants/globals.js` | `ASSIGNEE_TYPE`, `DISPLAY_MODE`, `STATUS_TYPE`, `CONVERSATION_TYPE`, `SORT_BY_TYPE`, `SNOOZE_OPTIONS`, `LAYOUT_TYPES` |
| `app/javascript/dashboard/constants/permissions.js` | `ASSIGNEE_TYPE_TAB_PERMISSIONS`, `DISPLAY_MODE_PERMISSIONS` |

## Điểm vào trên giao diện

- **Sidebar chính** (`app/javascript/dashboard/components-next/sidebar/Sidebar.vue`, ~dòng 396–520), nhóm "Conversations" gồm: **All** → route `home`; **Mentions** → `conversation_mentions`; **Participating** → `conversation_participating`; **Unattended** → `conversation_unattended`; **Folders** (danh sách custom view) → `folder_conversations`; **Teams** → `team_conversations`; **Channels** (inbox) → `inbox_dashboard`; **Labels** → `label_conversations`. Mỗi nhánh có badge số chưa đọc.
- **Trong danh sách**: tab Me/Unassigned/All (`ChatTypeTabs`), dropdown chế độ hiển thị (`ConversationDisplayMode`: default/company/vip), filter cơ bản status + sort ở header, nút filter nâng cao → modal `ConversationFilter`, nút lưu thành thư mục → `SaveCustomView`, nút xoá thư mục.
- **Context menu trên card hội thoại**: đổi status, snooze, priority, gán agent/team, thêm/bớt nhãn, đánh dấu đã đọc/chưa đọc, xoá hội thoại (dialog xác nhận).
- **Chọn nhiều card** → thanh `ConversationBulkActions`.
- **Màn hình chi tiết**: `ConversationHeader` (status, assignee, priority, `MoreActions`), `ReplyBox`, nút bật/tắt panel bên phải (`SidepanelSwitch`), 4 tab panel (Contact / Actions / History / Sales) và tab Company nếu bật feature `companies`.
- **Panel Actions** chứa ô đổi assignee/team/priority, nhãn, participant, và danh sách macro để chạy ngay trên hội thoại.
- **Command bar**: `CmdBarConversationSnooze.vue` (snooze qua palette).
- Từ chỗ khác: trang Contact → "View all conversations"; trang Deal/Ticket → tab hội thoại liên kết; tìm kiếm toàn cục → kết quả hội thoại.

## Luồng dữ liệu chính

**1) Tải danh sách hội thoại (không filter)**

```
Sidebar/route → ConversationView → ChatList.onMounted → resetAndFetchData()
  → store.dispatch('updateChatListFilters', conversationFilters)
  → store.dispatch('fetchAllConversations')
    → ConversationApi.get(state.conversationFilters)   (GET /api/v1/accounts/:id/conversations)
      → ConversationsController#index
        → ConversationFinder#perform
            set_inboxes (user.assigned_inboxes) → find_all_conversations
            → Conversations::PermissionFilterService (lọc theo inbox member, trừ admin)
            → filter_by_conversation_type / status / team / labels / query / source_id
            → set_count_for_all_conversations (COUNT FILTER mine/unassigned/all/vip)
            → filter_by_assignee_type → conversations (order VIP-waiting trước, rồi sort_by, page 25)
        → index.json.jbuilder → partials/_conversation (+ partial Enterprise cho SLA)
    → buildConversationList(): SET_ALL_CONVERSATION, conversationStats/set,
      conversationLabels/setBulkConversationLabels, contacts/SET_CONTACTS,
      conversationPage/setCurrentPage (+ setEndReached nếu payload rỗng)
  → getter getAllConversations / getMineChats / getUnAssignedChats / getAllStatusChats
  → ChatList.conversationList (lọc + sort lại ở client) → ConversationList → ConversationCard
```

**2) Lọc nâng cao / mở thư mục (custom view)**

```
ConversationFilter (modal) → onApplyFilter → applyConversationFilters
   hoặc  route folder_conversations → activeFolder.query
→ store.dispatch('fetchFilteredConversations', { queryData: filterQueryGenerator(payload), page })
  → POST /api/v1/accounts/:id/conversations/filter
    → ConversationsController#filter → Conversations::FilterService
       validate_query_operator → query_builder (dựa lib/filters/filter_keys.yml)
       → base_relation (includes + PermissionFilterService, có plan hint nếu lọc label equal_to)
       → order VIP trước, sort_on_last_activity_at, page
    → filter.json.jbuilder ({ meta, payload } – KHÔNG bọc "data")
  → buildConversationList(..., 'appliedFilters')
→ getter getFilteredConversations: matchesFilters(conversation, appliedFilters) + applyRoleFilter
→ ChatList còn lọc thêm lần nữa bằng matchesFilters(activeFolder.query.payload)
```

**3) Đổi trạng thái / realtime lan toả**

```
Card context menu hoặc ConversationHeader → ChatList.handleResolveConversation
  → (nếu feature conversation_required_attributes và thiếu thuộc tính) mở ConversationResolveAttributesModal
  → toggleConversationStatus → store 'toggleStatus'
    → (tuỳ chọn) POST /custom_attributes  → POST /:id/toggle_status
      → ConversationsController#toggle_status → set_conversation_status → conversation.save!
         (nếu open và user là agent → handle_human_open: xoá ai_assignee, tự nhận hội thoại)
      → Conversation callbacks: set_status_changed_at, handle_resolved_status_change (xoá waiting_since),
        notify_status_change → dispatch CONVERSATION_STATUS_CHANGED / RESOLVED / OPENED,
        create_activity (message activity), invalidate_filtered_unread_count_conversation,
        notify_conversation_updation → CONVERSATION_UPDATED
      → ActionCableListener.conversation_status_changed/updated → broadcast tới pubsub_token của
        inbox members + contact
      → (Enterprise) update_applied_sla_completion → applied_sla.completed_at
      → AutomationRuleListener, ReportingEventListener, NotificationListener, WebhookListener
    → commit CHANGE_CONVERSATION_STATUS (cập nhật lạc quan ở client)
  → WS 'conversation.updated' → store 'updateConversation' → UPDATE_CONVERSATION
```

## Feature flag & cấu hình

Khai báo flag: `config/features.yml` (backend) và `app/javascript/dashboard/featureFlags.js` (frontend).

| Flag | Ảnh hưởng tới mảng hội thoại |
|---|---|
| `sla` | Bật quan hệ/hiển thị SLA; partial Enterprise chỉ render `applied_sla`/`sla_events` khi bật; `permitted_update_params` chỉ nhận `sla_policy_id` khi bật. Mặc định `enabled: false`, nằm trong `CLOUD_PAID_FEATURES` |
| `conversation_unread_counts` | Bắt buộc cho `GET /conversations/unread_counts` (ngược lại 403) và cho broadcast `conversation.unread_count_changed` |
| `unread_count_for_filters` | Bộ đếm chưa đọc theo thư mục/bộ lọc (`Conversations::UnreadCounts::FilteredCounter::FEATURE_FLAG`); badge thư mục/mention/participating chỉ hiện khi bật |
| `conversation_required_attributes` | Bắt buộc điền custom attribute trước khi resolve; đọc `account.settings.conversation_required_attributes` |
| `companies` | Bật chế độ hiển thị "company" trong danh sách và tab Company trong sidebar |
| `crm_deals` / `crm_tickets` | Bật section Deals / Tickets trong panel bên phải |
| `linear_integration`, Shopify integration (`integrations/getIntegration`) | Bật section Linear / Shopify Orders |
| `macros`, `labels`, `custom_attributes`, `automations`, `canned_responses` | Bật các thao tác tương ứng |
| `auto_resolve_conversations` | Cho phép `Conversations::ResolutionJob` theo `account.auto_resolve_after`, `auto_resolve_message`, `auto_resolve_label`, `auto_resolve_ignore_waiting` |
| `channel_voice`, `tekomi_integration*` | Thêm voice call và trợ lý AI vào luồng hội thoại |

Cấu hình khác: biến môi trường `CONVERSATION_RESULTS_PER_PAGE` (mặc định `25`) trong `ConversationFinder#conversations`; `FRONTEND_URL` cho link CSAT; `ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT` / `ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT` ảnh hưởng `can_reply?`; UI settings per-user: `conversations_filter_by` (status + order_by), `conversation_display_mode`, `is_conversation_list_collapsed`, `is_contact_sidebar_open`, `conversation_sidebar_items_order`.

## i18n

- **Frontend** (`app/javascript/dashboard/i18n/locale/en/`):
  - `conversation.json` — khối `CONVERSATION`, `CONVERSATION_SIDEBAR`, `CONVERSATION_CUSTOM_ATTRIBUTES`, `CONVERSATION_PARTICIPANTS`, `EMAIL_TRANSCRIPT`, `TYPING`, `COPILOT`, `CONVERSATION_ANALYSIS`, `GALLERY_VIEW`, `TRANSLATE_MODAL`, `EMAIL_HEADER`, `ONBOARDING`
  - `chatlist.json` — khối `CHAT_LIST` (`ASSIGNEE_TYPE_TABS`, `CHAT_STATUS_FILTER_ITEMS`, `SORT_ORDER_ITEMS`, `DISPLAY_MODE`, `COLLAPSE_LIST`, …)
  - `advancedFilters.json` (`FILTER.ATTRIBUTES.*`), `macros.json`, `sla.json`, `snooze.json`, `bulkActions.json`, `labelsMgmt.json`, `search.json`, `contact.json`, `calls.json`
- **Backend**: `config/locales/en.yml` — khối `conversations:` (dòng ~303: `conversations.messages.*`, `conversations.activity.*`, `conversations.tekomi.handoff`) và `errors.conversations:` (dòng ~115: `resolved`, `unread_counts.feature_not_enabled`).
- Theo quy ước repo: chỉ sửa `en.yml` và `en.json`; các ngôn ngữ khác do Crowdin.

## ⚠️ Phụ thuộc chéo

1. **`conversations` là bảng trung tâm** — ít nhất 17 model `belongs_to :conversation`: `Message`, `Mention`, `ConversationParticipant`, `CsatSurveyResponse`, `ReportingEvent`, `AutomationRulePendingExecution`, `DealConversation`, `TicketConversation`, `PhoneCall`, `PhoneCallEmotionReport`, và (Enterprise) `AppliedSla`, `SlaEvent`, `ConversationAnalysis`, `ConversationOutcome`, `Call`, `Tekomi::FaqObservation`, `Tekomi::MessageReport`. Đổi vòng đời/cách xoá hội thoại ảnh hưởng Báo cáo, CSAT, CRM (Deals/Tickets), Voice và Tekomi AI.

2. **`taggings`/`tags` dùng chung giữa Hội thoại và Contact** (`Labelable` được include trong cả `Conversation` và `Contact`). `Label#update_associated_models` đổi tên nhãn sẽ ghi lại cả hai. Ngoài ra `conversations.cached_label_list` là bản sao CSV và được dùng trực tiếp trong SQL: `AppliedSla.filter_by_label_list` dùng `LIKE '%label%'` — sửa cách ghi `cached_label_list` sẽ làm sai báo cáo SLA.

3. **`ActionService` dùng chung giữa Macro và Automation Rules** (`Macros::ExecutionService < ActionService`, `AutomationRules::ActionService < ActionService`). Thêm/sửa một action (`change_status`, `add_label`, `assign_agent`, `snooze_conversation`, …) ảnh hưởng đồng thời cả hai mảng; whitelist `Macro::ACTIONS_ATTRS` phải được cập nhật song song.

4. **`custom_filters` dùng chung cho Hội thoại, Contact và Report** (`filter_type` enum). Sửa `CustomFiltersController` hoặc model ảnh hưởng cả "Thư mục hội thoại", "Phân khúc contact" và filter báo cáo. Lưu ý: Deal/Ticket dùng bảng **khác** (`saved_views`), đừng lẫn.

5. **`lib/filters/filter_keys.yml` dùng chung cho 3 nơi**: `Conversations::FilterService`, `Contacts::FilterService`, và `AutomationRules::ConditionsFilterService`/`ConditionValidationService`. Thêm attribute cho filter hội thoại cũng mở nó ra cho automation.

6. **`Conversations::PermissionFilterService` là chốt phân quyền duy nhất cho list/filter**, trong khi `ConversationPolicy#show?` là chốt cho từng bản ghi. Hai nơi dùng logic khác nhau (service chỉ xét inbox member; policy xét inbox **hoặc** team). Hệ quả: hội thoại gán cho team của bạn ở inbox bạn không thuộc vẫn mở được qua link trực tiếp nhưng không xuất hiện trong danh sách.

7. **`inboxes` / `inbox_members` quyết định mọi thứ**: `assigned_inboxes`, broadcast ActionCable (`conversation.inbox.members`), validate participant (`inbox.assignable_agents`), auto-assign (`inbox.member_ids_with_assignment_capacity`), `can_reply?` (theo `channel_type`). Đổi cấu hình inbox/thành viên inbox lan sang toàn bộ mảng hội thoại.

8. **`contacts.blocked` bị mute hội thoại ghi** — `Conversation#mute!` set `contact.blocked = true` cho **toàn bộ** contact, không chỉ hội thoại đang mute. `contact.blocked?` lại quyết định `determine_conversation_status` (hội thoại mới thành `resolved`) và `sla_applicable?`. Mute 1 hội thoại ảnh hưởng mọi hội thoại tương lai của contact đó.

9. **`contacts.vip` và `contacts.company_id` ảnh hưởng thứ tự & chế độ hiển thị**: `ConversationFinder` và `Conversations::FilterService` đều `ORDER BY (contact_id IN vip_contacts) DESC`; `DISPLAY_MODE.VIP`/`COMPANY` lọc theo `meta.sender.vip`/`company_id`. Đổi logic VIP/Company ở mảng Contact/Company sẽ đổi thứ tự danh sách hội thoại.

10. **Enterprise overlay bắt buộc kiểm tra song song**: `Conversation.prepend_mod_with('Conversation')`, `include_mod_with('Concerns::Conversation')`, `include_mod_with('Audit::Conversation')`; `ConversationFinder`, `Conversations::FilterService`, `Conversations::PermissionFilterService`, `ConversationPolicy`, `Conversations::EventDataPresenter`, `Api::V1::Accounts::ConversationsController` đều có `prepend_mod_with`. Sửa `list_of_keys`, `allowed_keys?`, `determine_conversation_status` hay `handle_resolved_status_change` ở OSS phải xem lại `enterprise/app/models/enterprise/conversation.rb` vì nó gọi `super`.

11. **`sla_policies` dùng chung giữa SLA hội thoại và SLA ticket**: ngoài `applied_slas`, repo còn có `ticket_stage_slas` và `SavedView::TICKET_DEFAULT_FILTERS` với `sla_status`. Đổi ngưỡng/ngữ nghĩa SLA ảnh hưởng cả hai mảng (*mức liên kết chi tiết giữa `SlaPolicy` và `TicketStageSla` chưa xác minh*).

12. **Bộ đếm chưa đọc (`Conversations::UnreadCounts::*`) bị invalidate từ nhiều mảng**: `Conversation` (các key trong `FILTERED_UNREAD_COUNT_UPDATE_KEYS`), `CustomFilter` (create/update/destroy), `ConversationParticipant` (create/destroy), và `ConversationsController#update_last_seen`. Thêm cột/thuộc tính mà quên thêm vào `FILTERED_UNREAD_COUNT_UPDATE_KEYS` sẽ làm badge sidebar lệch.

13. **`Message` ↔ `Conversation` hai chiều**: `last_activity_at`, `first_reply_created_at`, `waiting_since` đều được tin nhắn cập nhật. Mảng Tin nhắn và mảng Hội thoại không thể sửa độc lập.

## Cạm bẫy đã biết

- **`:id` trong route là `display_id`, không phải primary key**: `Current.account.conversations.find_by!(display_id: params[:id])`. Nhầm sang `id` sẽ mở sai hội thoại.
- **Hai endpoint danh sách trả hình dạng JSON khác nhau**: `index` bọc trong `json.data { meta, payload }`, còn `filter` trả thẳng `{ meta, payload }`. Store xử lý tương ứng (`data: { data }` vs `{ data }`). Đổi một bên mà quên bên kia làm danh sách trống không báo lỗi.
- **`filter.json.jbuilder` thiếu `assigned_count` và `vip_count`** (chỉ có mine/unassigned/all), vì `Conversations::FilterService#perform` không trả `vip_count`. Mọi UI đọc 2 key này khi đang áp filter sẽ nhận `undefined`.
- **Rất nhiều `catch { // Handle error }` nuốt lỗi** trong `store/modules/conversations/actions.js`: `getConversation`, `fetchAllConversations`, `fetchPreviousMessages`, `syncActiveConversationMessages`, `assignAgent`, `assignTeam`, `toggleStatus`, `muteConversation`, `markMessagesRead`… Khi API lỗi, UI im lặng và state giữ nguyên giá trị cũ. `fetchFilteredConversations` là ngoại lệ (có `throw`).
- **`markMessagesRead` commit sau `setTimeout(..., 4000)`**: badge chưa đọc chỉ xoá sau 4 giây; rời hội thoại sớm vẫn commit.
- **`update_last_seen` bị throttle 1 giờ** khi không có tin chưa đọc (`should_update_last_seen?`), nên `agent_last_seen_at` có thể cũ hơn thực tế.
- **`UPDATE_CONVERSATION` bỏ qua event cũ** bằng so sánh `conversation.updated_at < selectedConversation.updated_at` (`updated_at` là float giây). Hai cập nhật trong cùng mili-giây có thể bị bỏ; ngược lại nếu backend không đổi `updated_at` thì UI không cập nhật.
- **`SET_ALL_CONVERSATION` giữ nguyên `messages` của hội thoại đang chọn** (nhánh `else` cuối) — chủ ý để không mất tin, nhưng nghĩa là dữ liệu message của hội thoại đang mở không bao giờ được refresh từ danh sách.
- **`addConversation` early-return**: hội thoại mới từ websocket **không** được thêm vào store khi đang ở view Folder / Mentions / Participating / Unattended, hoặc khi `appliedFilters` không rỗng, hoặc khi `currentInbox` khác. Người dùng phải reload để thấy.
- **Lọc 2 lớp client + server**: `getFilteredConversations` chạy lại `matchesFilters` và `ChatList.conversationList` lọc thêm bằng `activeFolder.query.payload`. Nếu `filterHelpers.matchesFilters` không hỗ trợ cùng operator như `FilterService`, danh sách sẽ bị cắt mất bản ghi mà server đã trả về đúng.
- **`ConversationPolicy#destroy?` chỉ cho admin**, nhưng `ChatList` vẫn `provide('deleteConversation', ...)` cho mọi vai trò — agent bấm xoá sẽ nhận lỗi và thấy alert `FAIL_DELETE_CONVERSATION`.
- **`mute!` không chỉ là "tắt thông báo"**: nó `resolved!` hội thoại và block contact. Dễ hiểu sai từ tên API.
- **`POST /custom_attributes` mặc định ghi đè toàn bộ** `custom_attributes`; phải truyền `merge=true` để trộn. `toggleStatus` ở client gửi `customAttributes` đã trộn sẵn từ `getConversationById`, nên nếu store cũ sẽ ghi đè bằng dữ liệu lỗi thời.
- **`Macros::ExecutionService` bọc mỗi action trong `rescue StandardError` và chỉ gửi Sentry**: macro lỗi giữa chừng vẫn báo thành công cho người dùng.
- **`BulkActionsJob` dùng `conversation.update(params)` (không `!`)** nên bản ghi không hợp lệ bị bỏ qua im lặng; không có phản hồi lỗi về UI.
- **`ReopenSnoozedConversationsJob` chỉ quét `snoozed_until` trong `3.days.ago..Time.current`**: hội thoại snooze bị bỏ sót quá 3 ngày (job không chạy, downtime) sẽ **không bao giờ** tự mở lại.
- **`ensure_waiting_since` luôn set `waiting_since = created_at` khi tạo**, và `handle_resolved_status_change` dùng `update_column` để xoá `waiting_since` (bỏ qua callback/validation, không bắn event). Logic "unattended" và SLA NRT phụ thuộc cột này.
- **`load_attributes_created_by_db_triggers` phải `clear_attribute_changes(%w[display_id uuid])`** — comment trong code nói rõ: nếu để dirty thì `with_lock` trên hội thoại vừa tạo sẽ raise (ví dụ `ZaloOa::ConsultationWindow`). Đừng xoá dòng này.
- **`last_activity_at` chỉ có độ chính xác tới giây** (comment trong model): so sánh/copy giá trị trong Ruby dễ lệch; spec nên dùng `be_within(1.second)`.
- **`Conversation#toggle_status` có comment `FIXME: implement state machine`** và logic hai bước (`open? → resolved`, rồi `pending?/snoozed? → open`) — dễ hiểu sai khi đọc nhanh.
- **Enterprise `validate_sla_policy` không cho tháo hoặc đổi SLA policy** của hội thoại đã có SLA, và `ensure_applied_sla_is_created` bắt `RecordInvalid` rồi `raise ActiveRecord::Rollback` — lỗi SLA có thể âm thầm rollback cả lần save.
- **`Sla::EvaluateAppliedSlaService` early-return `unless conversation.sla_applicable?`** (contact bị block) nên SLA đứng im thay vì báo lỗi.
- **`PermissionFilterService#hinted_accessible_conversations` dùng `inbox_id + 0`** để chặn planner dùng index inbox (CW-7787). Đây là hack cố ý; đừng "dọn dẹp" nó.
- **`ConversationFinder#filter_by_query` lặp y nguyên điều kiện `messages.content ILIKE`** hai lần (có vẻ dư thừa) và dùng `joins(:messages)` + `includes(:messages)` nên có thể trả bản ghi trùng; đồng thời làm `set_count_for_all_conversations` rơi về nhánh `legacy_count_for_all_conversations` (eager loading).
- **`filter_by_status` bị bỏ qua hoàn toàn khi có `params[:q]`** (`filter_by_status unless params[:q]`): tìm kiếm luôn trả cả hội thoại đã resolve.
