CREATE TABLE IF NOT EXISTS `pawnshop_society_accounts` (
    `account_name` VARCHAR(64) NOT NULL,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pawnshop_transactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `transaction_type` VARCHAR(40) NOT NULL,
    `employee_citizenid` VARCHAR(64) NULL,
    `employee_name` VARCHAR(120) NULL,
    `customer_citizenid` VARCHAR(64) NULL,
    `customer_name` VARCHAR(120) NULL,
    `item_name` VARCHAR(100) NULL,
    `item_label` VARCHAR(150) NULL,
    `quantity` INT UNSIGNED NOT NULL DEFAULT 0,
    `customer_payout` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `appraiser_payout` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `profit` BIGINT NOT NULL DEFAULT 0,
    `society_balance_before` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `society_balance_after` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `metadata` LONGTEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_pawnshop_type` (`transaction_type`),
    KEY `idx_pawnshop_employee` (`employee_citizenid`),
    KEY `idx_pawnshop_customer` (`customer_citizenid`),
    KEY `idx_pawnshop_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
