%!
from alembic import op

"""A very small script template kept for Alembic compatibility."""

revision = '${up_revision}'
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}

def upgrade():
    pass


def downgrade():
    pass
