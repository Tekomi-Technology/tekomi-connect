const buildLcsTable = (left, right) => {
  const table = Array.from({ length: left.length + 1 }, () =>
    new Array(right.length + 1).fill(0)
  );

  for (let i = left.length - 1; i >= 0; i -= 1) {
    for (let j = right.length - 1; j >= 0; j -= 1) {
      table[i][j] =
        left[i] === right[j]
          ? table[i + 1][j + 1] + 1
          : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }

  return table;
};

const buildOperations = (left, right) => {
  const table = buildLcsTable(left, right);
  const operations = [];
  let i = 0;
  let j = 0;

  while (i < left.length && j < right.length) {
    if (left[i] === right[j]) {
      operations.push({ kind: 'keep', left: left[i], right: right[j], i, j });
      i += 1;
      j += 1;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      operations.push({ kind: 'removed', left: left[i], i });
      i += 1;
    } else {
      operations.push({ kind: 'added', right: right[j], j });
      j += 1;
    }
  }
  while (i < left.length) {
    operations.push({ kind: 'removed', left: left[i], i });
    i += 1;
  }
  while (j < right.length) {
    operations.push({ kind: 'added', right: right[j], j });
    j += 1;
  }

  return operations;
};

/**
 * Pairs a run of removed lines with the run of added lines that follows it, so
 * a replaced block shows side by side instead of as two separate stacks.
 */
const flushPending = (rows, removed, added) => {
  const length = Math.max(removed.length, added.length);

  for (let index = 0; index < length; index += 1) {
    const left = removed[index];
    const right = added[index];
    rows.push({
      kind: left && right ? 'changed' : left ? 'removed' : 'added',
      leftNumber: left ? left.i + 1 : null,
      leftText: left ? left.left : null,
      rightNumber: right ? right.j + 1 : null,
      rightText: right ? right.right : null,
    });
  }

  removed.length = 0;
  added.length = 0;
};

/**
 * Compares two blocks of text line by line.
 * @param {string} defaultBody - The inherited text.
 * @param {string} accountBody - The account's own text.
 * @returns {{rows: Array, addedCount: number, removedCount: number, keptCount: number}}
 */
export function lineDiff(defaultBody, accountBody) {
  const left = String(defaultBody ?? '').split('\n');
  const right = String(accountBody ?? '').split('\n');

  const rows = [];
  const pendingRemoved = [];
  const pendingAdded = [];
  let addedCount = 0;
  let removedCount = 0;
  let keptCount = 0;

  buildOperations(left, right).forEach(operation => {
    if (operation.kind === 'removed') {
      pendingRemoved.push(operation);
      removedCount += 1;
      return;
    }
    if (operation.kind === 'added') {
      pendingAdded.push(operation);
      addedCount += 1;
      return;
    }

    flushPending(rows, pendingRemoved, pendingAdded);
    keptCount += 1;
    rows.push({
      kind: 'keep',
      leftNumber: operation.i + 1,
      leftText: operation.left,
      rightNumber: operation.j + 1,
      rightText: operation.right,
    });
  });

  flushPending(rows, pendingRemoved, pendingAdded);

  return { rows, addedCount, removedCount, keptCount };
}
