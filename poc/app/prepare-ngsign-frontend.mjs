import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const [maarchRoot, pluginRoot] = process.argv.slice(2);
if (!maarchRoot || !pluginRoot) {
    throw new Error('Usage: node prepare-ngsign-frontend.mjs <maarch-root> <plugin-root>');
}

const frontendRoot = join(maarchRoot, 'src/frontend/app');
const componentRoot = join(frontendRoot, 'actions/send-external-signatory-book-action');

function read(path) {
    if (!existsSync(path)) {
        throw new Error(`Expected Maarch 2301 file not found: ${path}`);
    }
    return readFileSync(path, 'utf8');
}

function write(path, contents) {
    writeFileSync(path, contents);
}

function addAfterMatch(path, expression, addition, description) {
    let contents = read(path);
    if (contents.includes(addition.trim())) {
        return;
    }
    if (!expression.test(contents)) {
        throw new Error(`Could not find ${description} in ${path}`);
    }
    contents = contents.replace(expression, (match) => `${match}\n${addition}`);
    write(path, contents);
}

function addBeforeMatch(path, expression, addition, description) {
    let contents = read(path);
    if (contents.includes(addition.trim())) {
        return;
    }
    if (!expression.test(contents)) {
        throw new Error(`Could not find ${description} in ${path}`);
    }
    contents = contents.replace(expression, (match) => `${addition}\n${match}`);
    write(path, contents);
}

const files = ['ngsign.component.ts', 'ngsign.component.html', 'ngsign.component.scss'];
const targetDirectory = join(componentRoot, 'ngsign');
mkdirSync(targetDirectory, { recursive: true });
for (const file of files) {
    cpSync(join(pluginRoot, 'frontend', file), join(targetDirectory, file));
}

const appModule = join(frontendRoot, 'app.module.ts');
addAfterMatch(
    appModule,
    /import\s+\{\s*IParaphComponent\s*}\s+from\s+['"][^'"]+['"];?/,
    "import { NgsignComponent } from './actions/send-external-signatory-book-action/ngsign/ngsign.component';",
    'the IParaphComponent import'
);
addAfterMatch(
    appModule,
    /IParaphComponent,?\s*/,
    '        NgsignComponent,',
    'the IParaphComponent declaration'
);

const actionComponent = join(componentRoot, 'send-external-signatory-book-action.component.ts');
addAfterMatch(
    actionComponent,
    /import\s+\{\s*IParaphComponent\s*}\s+from\s+['"][^'"]+['"];?/,
    "import { NgsignComponent } from './ngsign/ngsign.component';",
    'the send-action IParaphComponent import'
);
addBeforeMatch(
    actionComponent,
    /\bconstructor\s*\(/,
    "    @ViewChild('ngsign', { static: false }) ngsign: NgsignComponent;",
    'the component constructor'
);

const actionTemplate = join(componentRoot, 'send-external-signatory-book-action.component.html');
let template = read(actionTemplate);
const ngsignElement = `<app-ngsign #ngsign *ngIf="authService.externalSignatoryBook.id === 'ngsign' && !loading"
    [additionalsInfos]="additionalsInfos"
    [externalSignatoryBookDatas]="externalSignatoryBookDatas">
</app-ngsign>`;
if (!template.includes('<app-ngsign')) {
    const iParaphElement = /<app-i-paraph\b[\s\S]*?<\/app-i-paraph>/;
    if (!iParaphElement.test(template)) {
        throw new Error(`Could not find the app-i-paraph element in ${actionTemplate}`);
    }
    template = template.replace(iParaphElement, (match) => `${match}\n${ngsignElement}`);
    write(actionTemplate, template);
}

console.log('NGSign Angular component wired into Maarch frontend sources.');
