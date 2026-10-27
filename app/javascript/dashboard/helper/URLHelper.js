export const frontendURL = (path, params) => {
  const stringifiedParams = params ? `?${new URLSearchParams(params)}` : '';
  return `/app/${path}${stringifiedParams}`;
};

export const CONVERSATION_LIST_QUERY_KEYS = [
  'inbox_id',
  'label',
  'team_id',
  'scope',
  'filter',
];

const SCOPE_FILTER_TYPES = ['mention', 'participating', 'unattended'];

export const conversationListQuery = ({
  inboxId,
  label,
  teamId,
  conversationType = '',
  filter,
}) => {
  const query = {};
  if (inboxId) query.inbox_id = String(inboxId);
  if (label) query.label = label;
  if (teamId) query.team_id = String(teamId);
  if (conversationType === 'mine') query.scope = 'mine';
  if (SCOPE_FILTER_TYPES.includes(conversationType)) {
    query.filter = conversationType;
  }
  if (filter) query.filter = filter;
  return query;
};

export const pickConversationListQuery = query =>
  Object.fromEntries(
    CONVERSATION_LIST_QUERY_KEYS.filter(key => query?.[key]).map(key => [
      key,
      query[key],
    ])
  );

const withQuery = (path, query) => {
  const search = new URLSearchParams(query).toString();
  return search ? `${path}?${search}` : path;
};

export const conversationUrl = ({
  accountId,
  activeInbox,
  id,
  label,
  teamId,
  conversationType = '',
  foldersId,
  filter,
}) => {
  if (foldersId && foldersId !== 0) {
    return `accounts/${accountId}/custom_view/${foldersId}/conversations/${id}`;
  }
  return withQuery(
    `accounts/${accountId}/conversations/${id}`,
    conversationListQuery({
      inboxId: activeInbox,
      label,
      teamId,
      conversationType,
      filter,
    })
  );
};

export const conversationListPageURL = ({
  accountId,
  conversationType = '',
  inboxId,
  label,
  teamId,
  customViewId,
  filter,
}) => {
  if (customViewId) {
    return frontendURL(`accounts/${accountId}/custom_view/${customViewId}`);
  }
  return frontendURL(
    withQuery(
      `accounts/${accountId}/dashboard`,
      conversationListQuery({
        inboxId,
        label,
        teamId,
        conversationType,
        filter,
      })
    )
  );
};

export const isValidURL = value => {
  /* eslint-disable no-useless-escape */
  const URL_REGEX =
    /^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$/gm;
  return URL_REGEX.test(value);
};

export const getArticleSearchURL = ({
  host,
  portalSlug,
  pageNumber,
  locale,
  status,
  authorId,
  categorySlug,
  sort,
  query,
}) => {
  const queryParams = new URLSearchParams({});

  const params = {
    page: pageNumber,
    locale,
    status,
    author_id: authorId,
    category_slug: categorySlug,
    sort,
    query,
  };

  Object.entries(params).forEach(([key, value]) => {
    if (value !== null && value !== undefined) {
      queryParams.set(key, value);
    }
  });

  return `${host}/${portalSlug}/articles?${queryParams.toString()}`;
};

export const hasValidAvatarUrl = avatarUrl => {
  try {
    const { host: avatarUrlHost } = new URL(avatarUrl);
    const isFromGravatar = ['www.gravatar.com', 'gravatar'].includes(
      avatarUrlHost
    );
    return avatarUrl && !isFromGravatar;
  } catch (error) {
    return false;
  }
};

export const timeStampAppendedURL = dataUrl => {
  // Attachment URLs can be app-relative (e.g. proxied call recordings),
  // so resolve them against the current origin before parsing.
  const url = new URL(dataUrl, window.location.origin);
  if (!url.searchParams.has('t')) {
    url.searchParams.append('t', Date.now());
  }

  return url.toString();
};

export const getHostNameFromURL = url => {
  try {
    return new URL(url).hostname;
  } catch (error) {
    return null;
  }
};

// Shared with the mobile app via @chatwoot/utils.
export { extractFilenameFromUrl } from '@chatwoot/utils';

/**
 * Normalizes a comma/newline separated list of domains
 * @param {string} domains - The comma/newline separated list of domains
 * @returns {string} - The normalized list of domains
 * - Converts newlines to commas
 * - Trims whitespace
 * - Lowercases entries
 * - Removes empty values
 * - De-duplicates while preserving original order
 */
export const sanitizeAllowedDomains = domains => {
  if (!domains) return '';

  const tokens = domains
    .replace(/\r\n/g, '\n')
    .replace(/\s*\n\s*/g, ',')
    .split(',')
    .map(d => d.trim().toLowerCase())
    .filter(d => d.length > 0);

  // De-duplicate while preserving order using Set and filter index
  const seen = new Set();
  const unique = tokens.filter(d => {
    if (seen.has(d)) return false;
    seen.add(d);
    return true;
  });

  return unique.join(',');
};
