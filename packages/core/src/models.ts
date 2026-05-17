export enum UserRole {
  GROWER = 'GROWER',
  PRODUCER = 'PRODUCER',
  TRANSPORTER = 'TRANSPORTER',
}

export enum CropType {
  PINOT_NOIR = 'PINOT_NOIR',
  CHARDONNAY = 'CHARDONNAY',
  RIESLING = 'RIESLING',
  CABERNET = 'CABERNET',
  MERLOT = 'MERLOT',
  SAUVIGNON_BLANC = 'SAUVIGNON_BLANC',
}

export enum ContainerType {
  MACRO_BIN = 'MACRO_BIN',
  HALF_BIN = 'HALF_BIN',
  LUG_BOX = 'LUG_BOX',
  BULK_BAG = 'BULK_BAG',
}

export enum PerishTier {
  HOURS_12 = 'HOURS_12',
  HOURS_24 = 'HOURS_24',
  DAYS_3 = 'DAYS_3',
  DAYS_7 = 'DAYS_7',
}

export enum ListingStatus {
  OPEN = 'OPEN',
  MATCHED = 'MATCHED',
  LOCKED = 'LOCKED',
  IN_TRANSIT = 'IN_TRANSIT',
  DELIVERED = 'DELIVERED',
  SETTLED = 'SETTLED',
  EXPIRED = 'EXPIRED',
  DISPUTED = 'DISPUTED',
}

export interface UserModel {
  uid: string;
  role: UserRole;
  displayName: string;
  phone: string;
  geoPoint: { latitude: number; longitude: number };
  geohash: string;
  radiusMiles: number;
  stripeAcctId?: string;
  verified: boolean;
  createdAt: Date;
  fcmTokens: string[];
}

export interface ListingModel {
  listingId: string;
  growerId: string;
  cropType: CropType;
  containerType: ContainerType;
  containerCount: number;
  weightKg: number;
  perishTier: PerishTier;
  askingPriceUSD: number;
  plotLocation: { latitude: number; longitude: number };
  geohash: string;
  harvestWindowEnd: Date;
  status: ListingStatus;
  producerId: string | null;
  transporterId: string | null;
  listingSource: 'AGENT' | 'MANUAL';
  createdAt: Date;
  updatedAt: Date;
}

export interface HandoffModel {
  handoffId: string;
  listingId: string;
  growerId: string;
  producerId: string;
  transporterId: string;
  contractHash: string;
  gate1?: {
    confirmedAt: Date;
    gps: { latitude: number; longitude: number };
    imageUrl: string;
    imageHash: string;
    transporterId: string;
  };
  gate2?: {
    confirmedAt: Date;
    gps: { latitude: number; longitude: number };
    imageUrl: string;
    imageHash: string;
    producerId: string;
  };
  payment?: {
    totalUSD: number;
    growerShareUSD: number;
    transporterFeeUSD: number;
    platformFeeUSD: number;
    stripePaymentId: string;
    releasedAt: Date | null;
  };
  disputeStatus: null | 'RAISED' | 'RESOLVED';
}

export interface AgentLogModel {
  logId: string;
  growerId: string;
  rawInput: string;
  geminiOutput: object;
  elasticQuery: object;
  elasticResult: object;
  listingId: string;
  processingMs: number;
  createdAt: Date;
}
