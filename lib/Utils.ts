export class Utils {
    public static isNotEmpty(str: string): boolean {
        return (!!str && !!str.trim());
    }

    public static getError(error: any): string {
        if (error && error.message) {
            return JSON.stringify(error.message);
        }

        return JSON.stringify(error);
    }
}
