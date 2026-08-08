import { Component, Input } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { NotificationService } from '@service/notification/notification.service';
import { HttpClient } from '@angular/common/http';

/**
 * NGSign send-dialog component (Option B — native `ngsign` id).
 *
 * Strict equivalent of Maarch's generic iParapheur component (`app-i-paraph`,
 * `IParaphComponent`) — same public contract, so the parent action
 * (`send-external-signatory-book-action`) drives it with NO code change:
 * it dispatches dynamically via `this[authService.externalSignatoryBook.id]`.
 * That is why the `@ViewChild` template ref name MUST be exactly `ngsign` (= the id).
 *
 * Verified against Maarch Courrier 2301 (this file is a faithful copy of
 * i-paraph.component.ts, only the selector, class name and templateUrl differ).
 * The signer, the signature position and the launch are all resolved server-side by
 * NgsignController::sendDatas().
 */
@Component({
    selector: 'app-ngsign',
    templateUrl: 'ngsign.component.html',
    styleUrls: ['ngsign.component.scss'],
})
export class NgsignComponent {

    @Input() additionalsInfos: any;
    @Input() externalSignatoryBookDatas: any;

    loading: boolean = false;

    currentAccount: any = null;
    usersWorkflowList: any[] = [];

    injectDatasParam = {
        resId: 0,
        editable: true
    };

    constructor(public translate: TranslateService, public http: HttpClient, private notify: NotificationService) { }

    /** Enables "Validate": valid as soon as there is a signable attachment. */
    isValidParaph() {
        if (this.additionalsInfos.attachments.length === 0) {
            return false;
        } else {
            return true;
        }
    }

    /** Resource ids sent for signature (the signable attachments). */
    getRessources() {
        return this.additionalsInfos.attachments.map((e: any) => e.res_id);
    }

    /** Payload merged into the action data (nothing NGSign-specific to add). */
    getDatas() {
        return this.externalSignatoryBookDatas;
    }
}
