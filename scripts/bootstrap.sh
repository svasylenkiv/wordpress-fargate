#!/usr/bin/env bash
# scripts/bootstrap.sh
# Одноразовий скрипт для створення Terraform backend та OIDC.
# Запускати локально з правами AWS Admin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../infrastructure/bootstrap"

# ── Кольори для виводу ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Передумови ────────────────────────────────────────────────────────────────
command -v terraform >/dev/null 2>&1 || error "terraform not found"
command -v aws       >/dev/null 2>&1 || error "aws CLI not found"

info "Перевірка AWS credentials..."
aws sts get-caller-identity --query 'Account' --output text || \
  error "AWS credentials не налаштовані. Запусти: aws configure"

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
info "AWS Account: ${ACCOUNT_ID}"

# ── Запит GitHub org/username ──────────────────────────────────────────────────
read -rp "Введи GitHub username або org: " GITHUB_ORG
read -rp "Введи назву репозиторію [wordpress-fargate]: " GITHUB_REPO
GITHUB_REPO="${GITHUB_REPO:-wordpress-fargate}"

# Sandbox SCP зазвичай дозволяє S3/DynamoDB лише в us-east-1
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION
info "AWS Region: ${AWS_REGION}"

# Старий plan міг бути з іншим регіоном — не застосовувати випадково
rm -f bootstrap.tfplan
info "Переходимо в bootstrap директорію..."
cd "${BOOTSTRAP_DIR}"

info "terraform init..."
terraform init

info "terraform plan..."
terraform plan \
  -var="aws_region=${AWS_REGION}" \
  -var="github_org=${GITHUB_ORG}" \
  -var="github_repo=${GITHUB_REPO}" \
  -out=bootstrap.tfplan

echo ""
warning "Перевір plan вище. Продовжити apply? (yes/no)"
read -r CONFIRM
[[ "${CONFIRM}" == "yes" ]] || error "Bootstrap скасовано."

info "terraform apply..."
terraform apply bootstrap.tfplan

# ── Вивести outputs ───────────────────────────────────────────────────────────
echo ""
info "=== Bootstrap завершено! ==="
echo ""
info "Збережи ці значення — вони потрібні для Terragrunt та GitHub Secrets:"
echo ""
terraform output -json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for k, v in data.items():
    print(f'  {k} = {v[\"value\"]}')
"

echo ""
info "Наступний крок: додай ці значення як GitHub Secrets:"
info "  TERRAFORM_ROLE_ARN  → github_actions_terraform_role_arn"
info "  DEPLOY_ROLE_ARN     → github_actions_deploy_role_arn"
info "  AWS_ACCOUNT_ID      → aws_account_id"